# db.py — Conexión MSSQL + helpers de negocio
# Requiere: pip install pyodbc

import pyodbc
from typing import List, Tuple, Optional, Dict, Any

# ==== CONFIGURA TU ENTORNO ====
SERVER   = r"DESKTOP-VS9VM60\SQLEXPRESS"   # <--- ajusta a tu instancia real
DATABASE = "Farmacia3H"
DRIVER   = "{ODBC Driver 18 for SQL Server}"

def conectar():
    """
    Abre una conexión a SQL Server. Si no usas SQL Browser, podrías usar SERVER='127.0.0.1,1433'.
    """
    conn_str = (
        f"DRIVER={DRIVER};"
        f"SERVER={SERVER};"
        f"DATABASE={DATABASE};"
        f"Trusted_Connection=yes;"
        f"Encrypt=no;"
        f"TrustServerCertificate=yes;"
        f"Connection Timeout=5;"
    )
    return pyodbc.connect(conn_str)

# ===================== Básicos =====================

def ping() -> str:
    cnx = conectar()
    try:
        with cnx.cursor() as cur:
            cur.execute("SELECT DB_NAME();")
            return cur.fetchone()[0]
    finally:
        cnx.close()

def validar_usuario(usuario: str, clave: str):
    """
    Valida usuario usando HASHBYTES(SHA2_256) en SQL Server.
    Devuelve (ok:bool, rol:str|None, id:int|None)
    """
    cnx = conectar()
    try:
        with cnx.cursor() as cur:
            cur.execute("""
                SELECT u.IdUsuario,
                       r.Nombre AS Rol,
                       CASE WHEN u.ClaveHash = HASHBYTES('SHA2_256', CONVERT(NVARCHAR(4000), ?))
                            AND u.Activo = 1 THEN 1 ELSE 0 END AS Ok
                FROM dbo.Usuarios u
                JOIN dbo.Roles r ON r.IdRol = u.RolId
                WHERE u.Usuario = ?;
            """, (clave, usuario))
            row = cur.fetchone()
            if not row:
                return False, None, None
            ok = bool(row.Ok)
            return (ok, row.Rol if ok else None, row.IdUsuario if ok else None)
    finally:
        cnx.close()

# ===================== Productos =====================

def productos_listar(buscar: str = "") -> List[Tuple]:
    """
    Lista productos. Si buscar != '', filtra por código o descripción.
    """
    sql = """
        SELECT IdProducto, Codigo, Descripcion, Precio, Stock, StockMin, RequiereReceta
        FROM dbo.Productos
    """
    params: Tuple[Any, ...] = ()
    if buscar:
        sql += " WHERE Codigo LIKE ? OR Descripcion LIKE ?"
        like = f"%{buscar}%"
        params = (like, like)
    sql += " ORDER BY Descripcion"
    cnx = conectar()
    try:
        with cnx.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchall()
    finally:
        cnx.close()

def producto_get_por_codigo(codigo: str) -> Optional[Tuple]:
    cnx = conectar()
    try:
        with cnx.cursor() as cur:
            cur.execute("""
                SELECT IdProducto, Codigo, Descripcion, Precio, Stock, StockMin, RequiereReceta
                FROM dbo.Productos WHERE Codigo = ?;
            """, (codigo,))
            return cur.fetchone()
    finally:
        cnx.close()

def producto_upsert(codigo: str, descripcion: str, precio: float, stockmin: int = 0, requiere_receta: bool = False) -> int:
    """
    Crea o actualiza producto (por Código). Devuelve IdProducto.
    """
    cnx = conectar()
    try:
        with cnx.cursor() as cur:
            cur.execute("SELECT IdProducto FROM dbo.Productos WHERE Codigo = ?;", (codigo,))
            row = cur.fetchone()
            if row:
                pid = int(row[0])
                cur.execute("""
                    UPDATE dbo.Productos
                    SET Descripcion=?, Precio=?, StockMin=?, RequiereReceta=?
                    WHERE IdProducto=?;
                """, (descripcion, float(precio), int(stockmin), 1 if requiere_receta else 0, pid))
                cnx.commit()
                return pid
            else:
                cur.execute("""
                    INSERT INTO dbo.Productos(Codigo, Descripcion, Precio, Stock, StockMin, RequiereReceta)
                    VALUES (?, ?, ?, 0, ?, ?);
                """, (codigo, descripcion, float(precio), int(stockmin), 1 if requiere_receta else 0))
                cur.execute("SELECT SCOPE_IDENTITY();")
                pid = int(cur.fetchone()[0])
                cnx.commit()
                return pid
    finally:
        cnx.close()

# ===================== Proveedores =====================

def proveedores_listar() -> List[Tuple[int, str]]:
    cnx = conectar()
    try:
        with cnx.cursor() as cur:
            cur.execute("SELECT IdProveedor, RazonSocial FROM dbo.Proveedores ORDER BY RazonSocial;")
            return [(int(r[0]), str(r[1])) for r in cur.fetchall()]
    finally:
        cnx.close()

# ===================== Sugerencias productos =====================

def productos_sugerir(term: str) -> List[Tuple[str, str, float, int]]:
    """
    Devuelve lista [(Codigo, Descripcion, Precio, Stock)] usando el sproc sp_productos_sugerir si existe,
    sino consulta fallback.
    """
    cnx = conectar()
    try:
        with cnx.cursor() as cur:
            try:
                cur.execute("EXEC dbo.sp_productos_sugerir @term = ?;", term)
                rows = cur.fetchall()
            except pyodbc.Error:
                cur.execute("""
                    SELECT TOP (10) Codigo, Descripcion, Precio, Stock
                    FROM dbo.Productos
                    WHERE Codigo LIKE ? OR Descripcion LIKE ?
                    ORDER BY Descripcion
                """, (term + "%", "%" + term + "%"))
                rows = cur.fetchall()
            return rows
    finally:
        cnx.close()

# ===================== Compras =====================

def compra_crear(usuario_id: int, proveedor_id: int, items: List[Dict[str, Any]], nro: Optional[str] = None) -> int:
    """
    Crea cabecera de compra y detalle.
    items: [{codigo, desc, cant, punit, vence:str|None}]
    - Si el producto no existe, lo crea (precio tomado de punit, stockmin=0).
    - Aumenta Stock en Productos.
    - Crea lote si 'vence' viene informado (formato YYYY-MM-DD).
    Devuelve IdCompra.
    """
    cnx = conectar()
    try:
        with cnx.cursor() as cur:
            total = sum(float(i["cant"]) * float(i["punit"]) for i in items)
            if nro is None:
                # genera algo tipo OC-<timestamp simple>
                cur.execute("SELECT RIGHT('000000'+CONVERT(VARCHAR(6), ISNULL(MAX(IdCompra),0)+1), 6) FROM dbo.Compras;")
                seq = cur.fetchone()[0]
                nro = f"OC-{seq}"

            cur.execute("""
                INSERT INTO dbo.Compras(Fecha, NroComprobante, IdProveedor, Total, UsuarioId)
                VALUES (SYSDATETIME(), ?, ?, ?, ?);
            """, (nro, int(proveedor_id), float(total), int(usuario_id)))
            cur.execute("SELECT SCOPE_IDENTITY();")
            idc = int(cur.fetchone()[0])

            for it in items:
                codigo = str(it["codigo"]).strip()
                desc   = str(it.get("desc", "")).strip()
                cant   = int(it["cant"])
                punit  = float(it["punit"])
                vence  = it.get("vence")  # None o 'YYYY-MM-DD'

                # asegura producto
                cur.execute("SELECT IdProducto FROM dbo.Productos WHERE Codigo=?;", (codigo,))
                r = cur.fetchone()
                if r:
                    pid = int(r[0])
                    # actualiza precio de lista a último punit (opcional)
                    cur.execute("UPDATE dbo.Productos SET Precio=? WHERE IdProducto=?;", (punit, pid))
                else:
                    cur.execute("""
                        INSERT INTO dbo.Productos(Codigo, Descripcion, Precio, Stock, StockMin, RequiereReceta)
                        VALUES (?, ?, ?, 0, 0, 0);
                    """, (codigo, desc if desc else codigo, punit))
                    cur.execute("SELECT SCOPE_IDENTITY();")
                    pid = int(cur.fetchone()[0])

                # aumenta stock general
                cur.execute("UPDATE dbo.Productos SET Stock = Stock + ? WHERE IdProducto=?;", (cant, pid))

                # lote opcional
                if vence:
                    cur.execute("""
                        INSERT INTO dbo.Lotes(IdProducto, Lote, Vence, StockLote)
                        VALUES (?, ?, ?, ?);
                    """, (pid, f"L-{idc}-{codigo}", vence, cant))

                # detalle compra
                cur.execute("""
                    INSERT INTO dbo.CompraDetalle(IdCompra, IdProducto, Cantidad, PrecioUnit)
                    VALUES (?, ?, ?, ?);
                """, (idc, pid, cant, punit))

            cnx.commit()
            return idc
    except:
        cnx.rollback()
        raise
    finally:
        cnx.close()

# ===================== Ventas =====================

def venta_crear(usuario_id: int, cliente_id: Optional[int], items: List[Dict[str, Any]], nro: Optional[str] = None) -> int:
    """
    Crea venta y detalle, descuenta stock.
    items: [{codigo, cant, punit}]
    No implementa FEFO por lote aquí (se descuenta del stock general).
    """
    cnx = conectar()
    try:
        with cnx.cursor() as cur:
            total = sum(float(i["cant"]) * float(i["punit"]) for i in items)
            if nro is None:
                cur.execute("SELECT RIGHT('000000'+CONVERT(VARCHAR(6), ISNULL(MAX(IdVenta),0)+1), 6) FROM dbo.Ventas;")
                seq = cur.fetchone()[0]
                nro = f"FAC-{seq}"

            cur.execute("""
                INSERT INTO dbo.Ventas(Fecha, NroComprobante, IdCliente, Total, UsuarioId)
                VALUES (SYSDATETIME(), ?, ?, ?, ?);
            """, (nro, cliente_id, float(total), int(usuario_id)))
            cur.execute("SELECT SCOPE_IDENTITY();")
            idv = int(cur.fetchone()[0])

            # valida y descuenta
            for it in items:
                codigo = str(it["codigo"]).strip()
                cant   = int(it["cant"])
                punit  = float(it["punit"])

                cur.execute("SELECT IdProducto, Stock, Precio FROM dbo.Productos WHERE Codigo=?;", (codigo,))
                r = cur.fetchone()
                if not r:
                    raise ValueError(f"Código {codigo} no existe.")
                pid, stock, precio = int(r[0]), int(r[1]), float(r[2])
                if stock < cant:
                    raise ValueError(f"Stock insuficiente para {codigo}. Disponible: {stock}")

                cur.execute("UPDATE dbo.Productos SET Stock = Stock - ? WHERE IdProducto=?;", (cant, pid))
                cur.execute("""
                    INSERT INTO dbo.VentaDetalle(IdVenta, IdProducto, Cantidad, PrecioUnit)
                    VALUES (?, ?, ?, ?);
                """, (idv, pid, cant, punit))

            cnx.commit()
            return idv
    except:
        cnx.rollback()
        raise
    finally:
        cnx.close()
