/* ============================================================
   Farmacia 3 Hermanas – Script COMPLETO (idempotente)
   Crea/actualiza todo el esquema, datos base y tabla de imágenes
   + mejoras: usuarios MERGE, vista/sproc de autocompletado, secuencia
   ============================================================ */

---------------------------------------------------------------
-- 0) Crear BD si no existe y usarla
---------------------------------------------------------------
IF DB_ID('Farmacia3H') IS NULL
    CREATE DATABASE Farmacia3H;
GO
USE Farmacia3H;
GO


/* ============================================================
   1) TABLAS (solo si no existen)
   ============================================================ */

-- ROLES
IF OBJECT_ID('dbo.Roles') IS NULL
BEGIN
  CREATE TABLE dbo.Roles(
    IdRol   INT IDENTITY(1,1) CONSTRAINT PK_Roles PRIMARY KEY,
    Nombre  VARCHAR(40) NOT NULL CONSTRAINT UQ_Roles_Nombre UNIQUE
  );
END
GO

-- USUARIOS
IF OBJECT_ID('dbo.Usuarios') IS NULL
BEGIN
  CREATE TABLE dbo.Usuarios(
    IdUsuario INT IDENTITY(1,1) CONSTRAINT PK_Usuarios PRIMARY KEY,
    Usuario   VARCHAR(40) NOT NULL CONSTRAINT UQ_Usuarios_Usuario UNIQUE,
    ClaveHash VARBINARY(256) NOT NULL,
    RolId     INT NOT NULL,
    Activo    BIT NOT NULL CONSTRAINT DF_Usuarios_Activo DEFAULT(1)
  );
END
GO

-- CLIENTES
IF OBJECT_ID('dbo.Clientes') IS NULL
BEGIN
  CREATE TABLE dbo.Clientes(
    IdCliente INT IDENTITY(1,1) CONSTRAINT PK_Clientes PRIMARY KEY,
    Documento VARCHAR(30)  NULL,
    Nombre    VARCHAR(120) NOT NULL,
    Telefono  VARCHAR(40)  NULL,
    Email     VARCHAR(120) NULL
  );
END
GO

-- PROVEEDORES
IF OBJECT_ID('dbo.Proveedores') IS NULL
BEGIN
  CREATE TABLE dbo.Proveedores(
    IdProveedor INT IDENTITY(1,1) CONSTRAINT PK_Proveedores PRIMARY KEY,
    Ruc         VARCHAR(30)  NOT NULL,
    RazonSocial VARCHAR(120) NOT NULL,
    Telefono    VARCHAR(40)  NULL,
    Email       VARCHAR(120) NULL
  );
END
GO

-- PRODUCTOS
IF OBJECT_ID('dbo.Productos') IS NULL
BEGIN
  CREATE TABLE dbo.Productos(
    IdProducto     INT IDENTITY(1,1) CONSTRAINT PK_Productos PRIMARY KEY,
    Codigo         VARCHAR(40)  NOT NULL CONSTRAINT UQ_Productos_Codigo UNIQUE,
    Descripcion    VARCHAR(160) NOT NULL,
    Precio         DECIMAL(18,2) NOT NULL CONSTRAINT CK_Productos_Precio CHECK (Precio>=0),
    Stock          INT NOT NULL CONSTRAINT DF_Productos_Stock DEFAULT(0) CONSTRAINT CK_Productos_Stock CHECK (Stock>=0),
    StockMin       INT NOT NULL CONSTRAINT DF_Productos_StockMin DEFAULT(0) CONSTRAINT CK_Productos_StockMin CHECK (StockMin>=0),
    RequiereReceta BIT NOT NULL CONSTRAINT DF_Productos_RequiereReceta DEFAULT(0)
  );
END
GO

-- LOTES (vencimientos por producto)
IF OBJECT_ID('dbo.Lotes') IS NULL
BEGIN
  CREATE TABLE dbo.Lotes(
    IdLote     INT IDENTITY(1,1) CONSTRAINT PK_Lotes PRIMARY KEY,
    IdProducto INT NOT NULL,
    Lote       VARCHAR(50) NOT NULL,
    Vence      DATE NOT NULL,
    StockLote  INT NOT NULL CONSTRAINT DF_Lotes_StockLote DEFAULT(0) CONSTRAINT CK_Lotes_StockLote CHECK (StockLote>=0)
  );
END
GO

-- VENTAS (cabecera)
IF OBJECT_ID('dbo.Ventas') IS NULL
BEGIN
  CREATE TABLE dbo.Ventas(
    IdVenta        INT IDENTITY(1,1) CONSTRAINT PK_Ventas PRIMARY KEY,
    Fecha          DATETIME2 NOT NULL CONSTRAINT DF_Ventas_Fecha DEFAULT (SYSDATETIME()),
    NroComprobante VARCHAR(30) NOT NULL CONSTRAINT UQ_Ventas_NroComprobante UNIQUE,
    IdCliente      INT NULL,
    Total          DECIMAL(18,2) NOT NULL CONSTRAINT CK_Ventas_Total CHECK (Total>=0),
    UsuarioId      INT NOT NULL
  );
END
GO

-- VENTAS (detalle)
IF OBJECT_ID('dbo.VentaDetalle') IS NULL
BEGIN
  CREATE TABLE dbo.VentaDetalle(
    IdDet      INT IDENTITY(1,1) CONSTRAINT PK_VentaDetalle PRIMARY KEY,
    IdVenta    INT NOT NULL,
    IdProducto INT NOT NULL,
    Cantidad   INT NOT NULL CONSTRAINT CK_VentaDetalle_Cant CHECK (Cantidad>0),
    PrecioUnit DECIMAL(18,2) NOT NULL CONSTRAINT CK_VentaDetalle_Precio CHECK (PrecioUnit>=0),
    Subtotal   AS (Cantidad * PrecioUnit) PERSISTED
  );
END
GO

-- COMPRAS (cabecera)
IF OBJECT_ID('dbo.Compras') IS NULL
BEGIN
  CREATE TABLE dbo.Compras(
    IdCompra       INT IDENTITY(1,1) CONSTRAINT PK_Compras PRIMARY KEY,
    Fecha          DATETIME2 NOT NULL CONSTRAINT DF_Compras_Fecha DEFAULT (SYSDATETIME()),
    NroComprobante VARCHAR(30) NOT NULL CONSTRAINT UQ_Compras_NroComprobante UNIQUE,
    IdProveedor    INT NOT NULL,
    Total          DECIMAL(18,2) NOT NULL CONSTRAINT CK_Compras_Total CHECK (Total>=0),
    UsuarioId      INT NOT NULL
  );
END
GO

-- COMPRAS (detalle)
IF OBJECT_ID('dbo.CompraDetalle') IS NULL
BEGIN
  CREATE TABLE dbo.CompraDetalle(
    IdDet      INT IDENTITY(1,1) CONSTRAINT PK_CompraDetalle PRIMARY KEY,
    IdCompra   INT NOT NULL,
    IdProducto INT NOT NULL,
    Cantidad   INT NOT NULL CONSTRAINT CK_CompraDetalle_Cant CHECK (Cantidad>0),
    PrecioUnit DECIMAL(18,2) NOT NULL CONSTRAINT CK_CompraDetalle_Precio CHECK (PrecioUnit>=0),
    Subtotal   AS (Cantidad * PrecioUnit) PERSISTED
  );
END
GO

-- PARAMETROS
IF OBJECT_ID('dbo.Parametros') IS NULL
BEGIN
  CREATE TABLE dbo.Parametros(
    Clave VARCHAR(60) NOT NULL CONSTRAINT PK_Parametros PRIMARY KEY,
    Valor NVARCHAR(4000) NOT NULL
  );
END
GO

-- CAJA
IF OBJECT_ID('dbo.CajaAperturas') IS NULL
BEGIN
  CREATE TABLE dbo.CajaAperturas(
    IdApertura   INT IDENTITY(1,1) CONSTRAINT PK_CajaAperturas PRIMARY KEY,
    FechaApertura DATETIME2 NOT NULL CONSTRAINT DF_CajaAperturas_FechaApertura DEFAULT (SYSDATETIME()),
    UsuarioId    INT NOT NULL,
    MontoInicial DECIMAL(18,2) NOT NULL CONSTRAINT DF_CajaAperturas_MontoInicial DEFAULT (0),
    Estado       CHAR(1) NOT NULL CONSTRAINT DF_CajaAperturas_Estado DEFAULT ('A'),
    FechaCierre  DATETIME2 NULL
  );
END
GO

IF OBJECT_ID('dbo.CajaMov') IS NULL
BEGIN
  CREATE TABLE dbo.CajaMov(
    IdMov       INT IDENTITY(1,1) CONSTRAINT PK_CajaMov PRIMARY KEY,
    IdApertura  INT NOT NULL,
    FechaHora   DATETIME2 NOT NULL CONSTRAINT DF_CajaMov_Fecha DEFAULT (SYSDATETIME()),
    Tipo        VARCHAR(10) NOT NULL, -- ING, EGR, VEN, COM
    Monto       DECIMAL(18,2) NOT NULL,
    Observacion NVARCHAR(300) NULL,
    RefVenta    INT NULL,
    RefCompra   INT NULL
  );
END
GO

IF OBJECT_ID('dbo.CajaCierres') IS NULL
BEGIN
  CREATE TABLE dbo.CajaCierres(
    IdCierre    INT IDENTITY(1,1) CONSTRAINT PK_CajaCierres PRIMARY KEY,
    IdApertura  INT NOT NULL,
    FechaCierre DATETIME2 NOT NULL CONSTRAINT DF_CajaCierres_Fecha DEFAULT (SYSDATETIME()),
    MontoConteo DECIMAL(18,2) NOT NULL,
    Diferencia  DECIMAL(18,2) NOT NULL
  );
END
GO

/* ============================================================
   X) IMÁGENES DE PRODUCTO (ilustraciones)
   ============================================================ */
IF OBJECT_ID('dbo.producto_imagenes') IS NULL
BEGIN
  CREATE TABLE dbo.producto_imagenes(
    id_imagen    INT IDENTITY(1,1) CONSTRAINT PK_producto_imagenes PRIMARY KEY,
    id_producto  INT NOT NULL,
    filename     NVARCHAR(255) NULL,
    mime_type    NVARCHAR(100) NULL,
    imagen       VARBINARY(MAX) NOT NULL,
    creado_en    DATETIME2 NOT NULL CONSTRAINT DF_producto_imagenes_creado_en DEFAULT SYSUTCDATETIME()
  );
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_producto_imagenes_productos')
  ALTER TABLE dbo.producto_imagenes ADD CONSTRAINT FK_producto_imagenes_productos
  FOREIGN KEY (id_producto) REFERENCES dbo.Productos(IdProducto) ON DELETE CASCADE;
GO


/* ============================================================
   2) CLAVES FORÁNEAS (si no existen)
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_Usuarios_Roles')
  ALTER TABLE dbo.Usuarios ADD CONSTRAINT FK_Usuarios_Roles
  FOREIGN KEY (RolId) REFERENCES dbo.Roles(IdRol);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_Lotes_Productos')
  ALTER TABLE dbo.Lotes ADD CONSTRAINT FK_Lotes_Productos
  FOREIGN KEY (IdProducto) REFERENCES dbo.Productos(IdProducto);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_Ventas_Clientes')
  ALTER TABLE dbo.Ventas ADD CONSTRAINT FK_Ventas_Clientes
  FOREIGN KEY (IdCliente) REFERENCES dbo.Clientes(IdCliente);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_Ventas_Usuarios')
  ALTER TABLE dbo.Ventas ADD CONSTRAINT FK_Ventas_Usuarios
  FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios(IdUsuario);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_VentaDetalle_Ventas')
  ALTER TABLE dbo.VentaDetalle ADD CONSTRAINT FK_VentaDetalle_Ventas
  FOREIGN KEY (IdVenta) REFERENCES dbo.Ventas(IdVenta);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_VentaDetalle_Productos')
  ALTER TABLE dbo.VentaDetalle ADD CONSTRAINT FK_VentaDetalle_Productos
  FOREIGN KEY (IdProducto) REFERENCES dbo.Productos(IdProducto);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_Compras_Proveedores')
  ALTER TABLE dbo.Compras ADD CONSTRAINT FK_Compras_Proveedores
  FOREIGN KEY (IdProveedor) REFERENCES dbo.Proveedores(IdProveedor);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_Compras_Usuarios')
  ALTER TABLE dbo.Compras ADD CONSTRAINT FK_Compras_Usuarios
  FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios(IdUsuario);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_CompraDetalle_Compras')
  ALTER TABLE dbo.CompraDetalle ADD CONSTRAINT FK_CompraDetalle_Compras
  FOREIGN KEY (IdCompra) REFERENCES dbo.Compras(IdCompra);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_CompraDetalle_Productos')
  ALTER TABLE dbo.CompraDetalle ADD CONSTRAINT FK_CompraDetalle_Productos
  FOREIGN KEY (IdProducto) REFERENCES dbo.Productos(IdProducto);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_CajaAperturas_Usuarios')
  ALTER TABLE dbo.CajaAperturas ADD CONSTRAINT FK_CajaAperturas_Usuarios
  FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios(IdUsuario);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_CajaMov_Aperturas')
  ALTER TABLE dbo.CajaMov ADD CONSTRAINT FK_CajaMov_Aperturas
  FOREIGN KEY (IdApertura) REFERENCES dbo.CajaAperturas(IdApertura);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_CajaCierres_Aperturas')
  ALTER TABLE dbo.CajaCierres ADD CONSTRAINT FK_CajaCierres_Aperturas
  FOREIGN KEY (IdApertura) REFERENCES dbo.CajaAperturas(IdApertura);
GO


/* ============================================================
   3) ÍNDICES (si no existen)
   ============================================================ */
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_Lotes_Vence' AND object_id=OBJECT_ID('dbo.Lotes'))
  CREATE INDEX IX_Lotes_Vence ON dbo.Lotes(Vence);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_Productos_Stock' AND object_id=OBJECT_ID('dbo.Productos'))
  CREATE INDEX IX_Productos_Stock ON dbo.Productos(Stock);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_VentaDetalle_Venta' AND object_id=OBJECT_ID('dbo.VentaDetalle'))
  CREATE INDEX IX_VentaDetalle_Venta ON dbo.VentaDetalle(IdVenta);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_CompraDetalle_Compra' AND object_id=OBJECT_ID('dbo.CompraDetalle'))
  CREATE INDEX IX_CompraDetalle_Compra ON dbo.CompraDetalle(IdCompra);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_CajaMov_Apertura' AND object_id=OBJECT_ID('dbo.CajaMov'))
  CREATE INDEX IX_CajaMov_Apertura ON dbo.CajaMov(IdApertura);
GO

-- Índice extra para autocompletar por Descripción
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_Productos_Descripcion' AND object_id=OBJECT_ID('dbo.Productos'))
  CREATE INDEX IX_Productos_Descripcion ON dbo.Productos(Descripcion);
GO


/* ============================================================
   4) PARÁMETROS (seed/actualización)
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM dbo.Parametros WHERE Clave='dias_vencimiento_alerta')
  INSERT INTO dbo.Parametros(Clave,Valor) VALUES ('dias_vencimiento_alerta','30');
IF NOT EXISTS (SELECT 1 FROM dbo.Parametros WHERE Clave='moneda')
  INSERT INTO dbo.Parametros(Clave,Valor) VALUES ('moneda','PYG');
IF NOT EXISTS (SELECT 1 FROM dbo.Parametros WHERE Clave='nombre_sistema')
  INSERT INTO dbo.Parametros(Clave,Valor) VALUES ('nombre_sistema','Farmacia 3 Hermanas');
-- Semilla secuencia de códigos
IF NOT EXISTS (SELECT 1 FROM dbo.Parametros WHERE Clave='seq_producto')
  INSERT INTO dbo.Parametros(Clave,Valor) VALUES ('seq_producto','0');
GO


/* ============================================================
   5) DATOS INICIALES (solo si no existen)
   ============================================================ */
-- Roles
IF NOT EXISTS (SELECT 1 FROM dbo.Roles)
  INSERT INTO dbo.Roles(Nombre) VALUES ('Administrador'),('Cajero'),('Farmacéutico');

-- Usuarios base (si no existen; más abajo los actualizo con MERGE)
IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Usuario='admin')
  INSERT INTO dbo.Usuarios(Usuario, ClaveHash, RolId, Activo)
  VALUES ('admin',  HASHBYTES('SHA2_256', CONVERT(NVARCHAR(4000),'admin123')), (SELECT IdRol FROM dbo.Roles WHERE Nombre='Administrador'), 1);

IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Usuario='cajero1')
  INSERT INTO dbo.Usuarios(Usuario, ClaveHash, RolId, Activo)
  VALUES ('cajero1',HASHBYTES('SHA2_256', CONVERT(NVARCHAR(4000),'1234')),     (SELECT IdRol FROM dbo.Roles WHERE Nombre='Cajero'),         1);

IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Usuario='farma1')
  INSERT INTO dbo.Usuarios(Usuario, ClaveHash, RolId, Activo)
  VALUES ('farma1', HASHBYTES('SHA2_256', CONVERT(NVARCHAR(4000),'farma123')), (SELECT IdRol FROM dbo.Roles WHERE Nombre='Farmacéutico'),   1);

-- Clientes demo
IF NOT EXISTS (SELECT 1 FROM dbo.Clientes)
  INSERT INTO dbo.Clientes (Documento, Nombre, Telefono, Email)
  VALUES ('1234567', 'Juan Pérez', '0991 111 111', 'juan@example.com'),
         ('7654321', 'María López', '0982 222 222', 'maria@example.com');

-- Proveedores demo
IF NOT EXISTS (SELECT 1 FROM dbo.Proveedores)
  INSERT INTO dbo.Proveedores (Ruc, RazonSocial, Telefono, Email)
  VALUES ('80012345-6', 'Distribuidora Farma S.A.', '021 123 456', 'ventas@farma.com'),
         ('80098765-4', 'Laboratorio X',           '021 987 654', 'contacto@labx.com');

-- Productos demo
IF NOT EXISTS (SELECT 1 FROM dbo.Productos)
  INSERT INTO dbo.Productos(Codigo,Descripcion,Precio,Stock,StockMin,RequiereReceta)
  VALUES ('AMOX500','Amoxicilina 500mg',12000,100,10,0),
         ('PARA500','Paracetamol 500mg', 6000,200,20,0),
         ('IBU400', 'Ibuprofeno 400mg',  8000,150,15,0);

-- Lotes demo
IF NOT EXISTS (SELECT 1 FROM dbo.Lotes)
BEGIN
  INSERT INTO dbo.Lotes (IdProducto, Lote, Vence, StockLote)
  SELECT IdProducto, 'L-001', DATEFROMPARTS(YEAR(GETDATE())+1,  2,  1), 50 FROM dbo.Productos WHERE Codigo='AMOX500'
  UNION ALL
  SELECT IdProducto, 'L-010', DATEFROMPARTS(YEAR(GETDATE()),    11, 15), 70 FROM dbo.Productos WHERE Codigo='PARA500'
  UNION ALL
  SELECT IdProducto, 'L-020', DATEADD(DAY, 180, CAST(GETDATE() AS DATE)), 40 FROM dbo.Productos WHERE Codigo='IBU400';
END

-- Venta demo (solo si no hay ventas)
IF NOT EXISTS (SELECT 1 FROM dbo.Ventas)
BEGIN
  DECLARE @idCliente INT = (SELECT TOP 1 IdCliente FROM dbo.Clientes ORDER BY IdCliente);
  DECLARE @idUsuario INT = (SELECT TOP 1 IdUsuario FROM dbo.Usuarios WHERE Usuario='admin');
  INSERT INTO dbo.Ventas(Fecha, NroComprobante, IdCliente, Total, UsuarioId)
  VALUES (SYSDATETIME(), 'FAC-000001', @idCliente, 20000, @idUsuario);

  DECLARE @idVenta INT = SCOPE_IDENTITY();
  DECLARE @prod1 INT = (SELECT IdProducto FROM dbo.Productos WHERE Codigo='PARA500');
  INSERT INTO dbo.VentaDetalle(IdVenta, IdProducto, Cantidad, PrecioUnit)
  VALUES (@idVenta, @prod1, 2, 10000);
END

-- Compra demo (solo si no hay compras)
IF NOT EXISTS (SELECT 1 FROM dbo.Compras)
BEGIN
  DECLARE @idProv INT = (SELECT TOP 1 IdProveedor FROM dbo.Proveedores ORDER BY IdProveedor);
  DECLARE @idUsuario2 INT = (SELECT TOP 1 IdUsuario FROM dbo.Usuarios WHERE Usuario='admin');
  INSERT INTO dbo.Compras(Fecha, NroComprobante, IdProveedor, Total, UsuarioId)
  VALUES (SYSDATETIME(), 'OC-000001', @idProv, 30000, @idUsuario2);

  DECLARE @idCompra INT = SCOPE_IDENTITY();
  DECLARE @prod2 INT = (SELECT IdProducto FROM dbo.Productos WHERE Codigo='AMOX500');
  INSERT INTO dbo.CompraDetalle(IdCompra, IdProducto, Cantidad, PrecioUnit)
  VALUES (@idCompra, @prod2, 3, 10000);
END
GO


/* ============================================================
   6) UTILIDAD: crear/actualizar usuarios con HASHBYTES
   ============================================================ */
IF OBJECT_ID('dbo.sp_upsert_usuario', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_upsert_usuario;
GO
CREATE PROCEDURE dbo.sp_upsert_usuario
    @Usuario    VARCHAR(40),
    @ClavePlana NVARCHAR(4000),
    @RolNombre  VARCHAR(40),
    @Activo     BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @RolId INT = (SELECT IdRol FROM dbo.Roles WHERE Nombre=@RolNombre);
    IF @RolId IS NULL
        THROW 50001, 'Rol no existe', 1;

    IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Usuario=@Usuario)
        UPDATE dbo.Usuarios
          SET ClaveHash = HASHBYTES('SHA2_256', CONVERT(NVARCHAR(4000),@ClavePlana)),
              RolId     = @RolId,
              Activo    = @Activo
        WHERE Usuario=@Usuario;
    ELSE
        INSERT INTO dbo.Usuarios(Usuario, ClaveHash, RolId, Activo)
        VALUES (@Usuario, HASHBYTES('SHA2_256', CONVERT(NVARCHAR(4000),@ClavePlana)), @RolId, @Activo);
END
GO


/* ============================================================
   7) FEFO en ventas (descargar por Lotes que vencen primero)
   ============================================================ */

-- 7.1 Agregar columna IdLote al detalle de ventas
IF COL_LENGTH('dbo.VentaDetalle', 'IdLote') IS NULL
BEGIN
    ALTER TABLE dbo.VentaDetalle
        ADD IdLote INT NULL;
END
GO

-- 7.2 FK VentaDetalle.IdLote -> Lotes.IdLote
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_VentaDetalle_Lotes')
BEGIN
    ALTER TABLE dbo.VentaDetalle
        ADD CONSTRAINT FK_VentaDetalle_Lotes
        FOREIGN KEY (IdLote) REFERENCES dbo.Lotes(IdLote);
END
GO

-- 7.3 Índices FEFO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Lotes_Producto_Vence' AND object_id=OBJECT_ID('dbo.Lotes'))
BEGIN
    CREATE INDEX IX_Lotes_Producto_Vence ON dbo.Lotes(IdProducto, Vence);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Lotes_Producto_Stock' AND object_id=OBJECT_ID('dbo.Lotes'))
BEGIN
    CREATE INDEX IX_Lotes_Producto_Stock ON dbo.Lotes(IdProducto, StockLote);
END
GO


/* ============================================================
   8) USUARIOS DE PRUEBA (MERGE: asegura claves/roles)
   ============================================================ */

;MERGE dbo.Usuarios AS T
USING (SELECT 'admin' AS Usuario,
              HASHBYTES('SHA2_256', CONVERT(NVARCHAR(4000),'admin123')) AS ClaveHash,
              (SELECT IdRol FROM dbo.Roles WHERE Nombre='Administrador') AS RolId,
              CAST(1 AS BIT) AS Activo) AS S
ON T.Usuario = S.Usuario
WHEN MATCHED THEN UPDATE SET T.ClaveHash=S.ClaveHash, T.RolId=S.RolId, T.Activo=S.Activo
WHEN NOT MATCHED THEN INSERT(Usuario, ClaveHash, RolId, Activo) VALUES(S.Usuario, S.ClaveHash, S.RolId, S.Activo);

;MERGE dbo.Usuarios AS T
USING (SELECT 'cajero1' AS Usuario,
              HASHBYTES('SHA2_256', CONVERT(NVARCHAR(4000),'1234')) AS ClaveHash,
              (SELECT IdRol FROM dbo.Roles WHERE Nombre='Cajero') AS RolId,
              CAST(1 AS BIT) AS Activo) AS S
ON T.Usuario = S.Usuario
WHEN MATCHED THEN UPDATE SET T.ClaveHash=S.ClaveHash, T.RolId=S.RolId, T.Activo=S.Activo
WHEN NOT MATCHED THEN INSERT(Usuario, ClaveHash, RolId, Activo) VALUES(S.Usuario, S.ClaveHash, S.RolId, S.Activo);

;MERGE dbo.Usuarios AS T
USING (SELECT 'farma1' AS Usuario,
              HASHBYTES('SHA2_256', CONVERT(NVARCHAR(4000),'farma123')) AS ClaveHash,
              (SELECT IdRol FROM dbo.Roles WHERE Nombre='Farmacéutico') AS RolId,
              CAST(1 AS BIT) AS Activo) AS S
ON T.Usuario = S.Usuario
WHEN MATCHED THEN UPDATE SET T.ClaveHash=S.ClaveHash, T.RolId=S.RolId, T.Activo=S.Activo
WHEN NOT MATCHED THEN INSERT(Usuario, ClaveHash, RolId, Activo) VALUES(S.Usuario, S.ClaveHash, S.RolId, S.Activo);
GO


/* ============================================================
   9) AUTOCOMPLETADO DE PRODUCTOS (vista + sproc)
   ============================================================ */

-- Vista simple para búsqueda
IF OBJECT_ID('dbo.vw_productos_busqueda', 'V') IS NOT NULL
    DROP VIEW dbo.vw_productos_busqueda;
GO
CREATE VIEW dbo.vw_productos_busqueda
AS
SELECT p.IdProducto, p.Codigo, p.Descripcion, p.Precio, p.Stock, p.StockMin, p.RequiereReceta
FROM dbo.Productos p;
GO

-- Sugerencias TOP 10 por término (código inicia o descripción contiene)
IF OBJECT_ID('dbo.sp_productos_sugerir', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_productos_sugerir;
GO
CREATE PROCEDURE dbo.sp_productos_sugerir
    @term NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (10)
           p.Codigo, p.Descripcion, p.Precio, p.Stock
    FROM dbo.Productos p
    WHERE p.Codigo LIKE @term + '%'
       OR p.Descripcion LIKE '%' + @term + '%'
    ORDER BY
        CASE WHEN p.Codigo LIKE @term + '%' THEN 0 ELSE 1 END,
        p.Descripcion;
END
GO


/* ============================================================
   10) SECUENCIA OPCIONAL DE CÓDIGO DE PRODUCTO (Parametros)
   ============================================================ */

IF OBJECT_ID('dbo.sp_seq_producto_next', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_seq_producto_next;
GO
CREATE PROCEDURE dbo.sp_seq_producto_next
    @next INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    -- lee y aumenta Parametros.seq_producto de manera transaccional
    BEGIN TRAN;
        DECLARE @curr INT =
          TRY_CAST((SELECT Valor FROM dbo.Parametros WITH (UPDLOCK, ROWLOCK) WHERE Clave='seq_producto') AS INT);

        IF @curr IS NULL
        BEGIN
            SET @curr = 0;
            MERGE dbo.Parametros AS T
            USING (SELECT 'seq_producto' Clave, '0' Valor) AS S
            ON T.Clave = S.Clave
            WHEN NOT MATCHED THEN INSERT(Clave,Valor) VALUES(S.Clave,S.Valor);
        END

        SET @next = @curr + 1;
        UPDATE dbo.Parametros SET Valor = CONVERT(NVARCHAR(20), @next) WHERE Clave='seq_producto';
    COMMIT TRAN;
END
GO


/* ============================================================
   11) Verificaciones rápidas
   ============================================================ */
SELECT TOP 3 * FROM dbo.VentaDetalle ORDER BY IdDet DESC;
SELECT TOP 3 * FROM dbo.Lotes ORDER BY Vence ASC;
SELECT Usuario, CONVERT(VARCHAR(64), ClaveHash, 2) AS HashHex FROM dbo.Usuarios ORDER BY Usuario;
