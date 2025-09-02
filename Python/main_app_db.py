# main_app_db.py — Ventana principal con Notebook
# Integra Inventario, Compras y Ventas

import ttkbootstrap as tb
from ttkbootstrap.dialogs import Messagebox
from ttkbootstrap.constants import PRIMARY, INFO, WARNING

import db
from inventario_view import InventarioFrame
from compras_view import ComprasFrame
from ventas_view import VentasFrame


class MainApp(tb.Toplevel):
    def __init__(self, parent=None, usuario: str = "", rol: str = "", usuario_id: int | None = None):
        super().__init__(parent)
        self.title("Farmacia 3 Hermanas – Sistema de Gestión")
        self.geometry("1200x720")
        self.minsize(1000, 640)

        self.usuario = usuario
        self.rol = rol
        self.usuario_id = usuario_id

        self._build_ui()

    def _build_ui(self):
        top = tb.Frame(self, padding=10)
        top.pack(fill="x")

        tb.Label(top, text=f"Usuario: {self.usuario} | Rol: {self.rol}", bootstyle=PRIMARY)\
            .pack(side="left")

        tb.Button(top, text="Probar BD", bootstyle=INFO, command=self._probe_db)\
            .pack(side="right", padx=(8, 0))
        tb.Button(top, text="Cerrar", bootstyle=WARNING, command=self.destroy)\
            .pack(side="right")

        nb = tb.Notebook(self)
        nb.pack(fill="both", expand=True, padx=10, pady=10)

        self.tab_inv  = InventarioFrame(nb)
        self.tab_com  = ComprasFrame(nb, usuario_id=self.usuario_id)
        self.tab_ven  = VentasFrame(nb, usuario_id=self.usuario_id)

        nb.add(self.tab_inv, text="Inventario")
        nb.add(self.tab_com, text="Compras")
        nb.add(self.tab_ven, text="Ventas")

        status = tb.Frame(self)
        status.pack(fill="x", side="bottom")
        tb.Label(status, text="© Farmacia 3 Hermanas").pack(side="left", padx=8, pady=4)

    def _probe_db(self):
        try:
            base = db.ping()
            Messagebox.show_info(f"Conectado a: {base}", "BD", parent=self)
        except Exception as e:
            Messagebox.show_error(f"No se pudo conectar a la BD.\n\n{e}", "BD", parent=self)


# Prueba directa
if __name__ == "__main__":
    root = tb.Window(themename="flatly")
    root.withdraw()
    MainApp(root, usuario="admin", rol="Administrador", usuario_id=1).wait_window()
    root.destroy()
