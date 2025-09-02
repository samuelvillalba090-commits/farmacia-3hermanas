# -*- coding: utf-8 -*-
# Login moderno con ttkbootstrap (tema, logo) + errores en español

import os
import sys
import traceback

import ttkbootstrap as tb
from ttkbootstrap.dialogs import Messagebox
from ttkbootstrap.constants import SUCCESS, DANGER
from PIL import Image, ImageTk

import db
from main_app_db import MainApp

APP_THEME = "flatly"  # "cosmo", "darkly", etc.
LOGO_PATH = os.path.join("assets", "logo.png")  # coloca tu logo aquí


class LoginApp(tb.Window):
    def __init__(self):
        super().__init__(themename=APP_THEME)
        self.title("Farmacia 3 Hermanas | Inicio de Sesión")
        self.geometry("560x420")
        self.minsize(520, 400)
        self._center(560, 420)

        self.report_callback_exception = self._tk_error_es

        self.var_user = tb.StringVar(value="")
        self.var_pass = tb.StringVar(value="")
        self.var_show = tb.BooleanVar(value=False)

        self._build_ui()

        try:
            base = db.ping()
            print(f"Conectado a: {base}")
        except Exception as e:
            Messagebox.show_error(f"No se pudo conectar a la BD.\n\n{e}", "BD", parent=self)

    def _center(self, w, h):
        sw, sh = self.winfo_screenwidth(), self.winfo_screenheight()
        x, y = (sw - w) // 2, (sh - h) // 2
        self.geometry(f"{w}x{h}+{x}+{y}")

    def _build_ui(self):
        frm = tb.Frame(self, padding=16)
        frm.pack(fill="both", expand=True)

        header = tb.Frame(frm)
        header.pack(fill="x", pady=(0, 10))

        if os.path.exists(LOGO_PATH):
            try:
                img = Image.open(LOGO_PATH).resize((48, 48), Image.LANCZOS)
                self._logo_imgtk = ImageTk.PhotoImage(img)
                tb.Label(header, image=self._logo_imgtk).pack(side="left", padx=(0, 8))
            except Exception:
                pass

        tb.Label(header, text="Farmacia 3 Hermanas", font=("Segoe UI", 16, "bold")).pack(side="left", anchor="w")

        body = tb.LabelFrame(frm, text="Inicio de sesión", bootstyle="secondary")
        body.pack(fill="x", padx=4, pady=8)

        tb.Label(body, text="Usuario:").grid(row=0, column=0, sticky="w", padx=6, pady=8)
        ent_user = tb.Entry(body, textvariable=self.var_user, width=30)
        ent_user.grid(row=0, column=1, sticky="ew", padx=6, pady=8)

        tb.Label(body, text="Contraseña:").grid(row=1, column=0, sticky="w", padx=6, pady=8)
        self.ent_pass = tb.Entry(body, textvariable=self.var_pass, show="*", width=30)
        self.ent_pass.grid(row=1, column=1, sticky="ew", padx=6, pady=8)

        tb.Checkbutton(body, text="Mostrar contraseña", variable=self.var_show,
                       command=lambda: self.ent_pass.config(show="" if self.var_show.get() else "*")
                       ).grid(row=2, column=1, sticky="w", padx=6, pady=(0, 8))

        body.columnconfigure(1, weight=1)

        bar = tb.Frame(frm)
        bar.pack(fill="x", pady=10)

        tb.Button(bar, text="Ingresar", bootstyle=SUCCESS, command=self._login).pack(side="left")
        tb.Button(bar, text="Cancelar / Salir", bootstyle=DANGER, command=self.destroy).pack(side="left", padx=8)

        self.bind("<Return>", lambda e: self._login())
        ent_user.focus_set()

    def _login(self):
        u, p = self.var_user.get().strip(), self.var_pass.get().strip()
        if not u or not p:
            Messagebox.show_warning("Por favor complete usuario y contraseña.", "Campos vacíos", parent=self)
            return
        try:
            ok, rol, uid = db.validar_usuario(u, p)
            if not ok:
                Messagebox.show_error("Usuario o contraseña incorrectos.", "Acceso denegado", parent=self)
                return

            try:
                self.withdraw()
                main = MainApp(self, usuario=u, rol=rol, usuario_id=uid)
                main.protocol("WM_DELETE_WINDOW", main.destroy)
                main.wait_window()
            except Exception as e:
                Messagebox.show_error(f"No se pudo abrir el menú principal.\n\n{e}", "App", parent=self)
            finally:
                self.deiconify()
        except Exception as e:
            Messagebox.show_error(f"No se pudo validar contra la BD.\n\n{e}", "BD", parent=self)

    def _tk_error_es(self, exc, val, tbk):
        try:
            print("".join(traceback.format_exception(exc, val, tbk)), file=sys.stderr)
            Messagebox.show_error(f"Ocurrió un error inesperado.\n\n{val}", "Error", parent=self)
        except Exception:
            print(val, file=sys.stderr)


if __name__ == "__main__":
    app = LoginApp()
    app.mainloop()
