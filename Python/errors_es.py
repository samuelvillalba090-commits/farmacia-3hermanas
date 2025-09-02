# errors_es.py
# -*- coding: utf-8 -*-
"""
Traducción de errores a mensajes en español para la app Farmacia 3 Hermanas.
Uso: from errors_es import err_es
     messagebox.showerror("Error", err_es(e))
"""

import re
import pyodbc

_PATTERNS = [
    # Conexión / Driver
    (r"odbc driver.*not found|data source name not found", "No se encontró el driver ODBC solicitado. Verifique que el ODBC esté instalado."),
    (r"\[odbc driver 18.*\].*certificate|trust.*certificate", "Conexión cifrada falló: certificado no confiable. En local usamos TrustServerCertificate=yes (ya está en db.py)."),
    (r"login failed for user|28000", "Error de inicio de sesión: usuario o contraseña incorrectos, o sin permisos."),
    (r"timeout expired|hyt00", "Tiempo de espera agotado al comunicarse con la base de datos."),
    (r"communication link failure|08001|08s01|network.*related", "No se pudo conectar al servidor SQL. Verifique que el servicio esté en ejecución y la red disponible."),

    # Restricciones / DML
    (r"violation of unique key|unique constraint|duplicat.*key", "Dato duplicado: ya existe un registro con ese valor único."),
    (r"cannot insert the value null|cannot insert null", "Dato obligatorio faltante. Complete todos los campos requeridos."),
    (r"conflicted with the foreign key constraint", "No se puede eliminar/modificar porque está relacionado con otros datos (clave foránea)."),
    (r"check constraint.*violated", "Uno de los valores no cumple las reglas del sistema (restricción CHECK)."),
    (r"string or binary data would be truncated", "El texto es demasiado largo para el campo. Reduzca el contenido."),
    (r"conversion failed|failed to convert|varchar.*int|date.*conversion", "Formato de dato inválido. Revise números y fechas."),
    (r"deadlock|was deadlocked on lock resources", "Conflicto de concurrencia (deadlock). Intente nuevamente."),

    # SQL generales
    (r"invalid column name", "Nombre de columna inválido en la consulta."),
    (r"invalid object name", "Tabla o vista no existe."),
]

def _map_pyodbc_to_spanish(msg: str) -> str:
    txt = msg.lower()
    for pat, es in _PATTERNS:
        if re.search(pat, txt):
            return es
    return ""  # no match

def err_es(e: Exception) -> str:
    """
    Devuelve un mensaje en español para mostrar al usuario final.
    Intenta traducir errores comunes de pyodbc/SQL Server y Python.
    """
    if isinstance(e, pyodbc.Error):
        for part in map(str, e.args):
            if not part:
                continue
            mapped = _map_pyodbc_to_spanish(part)
            if mapped:
                return mapped
        return "Error de base de datos: " + (str(e).split(']')[-1].strip() or "consulte al administrador.")

    if isinstance(e, ValueError):
        return str(e)

    txt = str(e)
    lo = txt.lower()
    if "file not found" in lo or "no such file" in lo:
        return "Archivo no encontrado. Verifique la ruta."
    if "permission denied" in lo:
        return "Permiso denegado. Ejecute con privilegios o cambie la ruta."
    if "division by zero" in lo:
        return "No se puede dividir por cero."
    if "keyerror" in lo:
        return "Clave inexistente en la estructura de datos."
    if "indexerror" in lo:
        return "Índice fuera de rango."
    if "typeerror" in lo:
        return "Tipo de dato inválido en la operación solicitada."

    return txt or "Ocurrió un error no especificado."
