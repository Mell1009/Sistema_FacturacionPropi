/* =====================================================================
   run_all.sql - Despliega TODA la base de datos en orden.
   Requiere modo SQLCMD.

   Desde terminal (recomendado), parado dentro de la carpeta db/ :
       sqlcmd -S localhost -E -b -f 65001 -i run_all.sql
     -S  instancia local (cambiar si usan .\SQLEXPRESS u otra)
     -E  autenticación de Windows (admin local que despliega)
     -b  aborta si hay error
     -f 65001  lee los .sql como UTF-8 (tildes y ñ)

   Desde SSMS: menú Query > SQLCMD Mode, y cambiar RUTA por la ruta
   absoluta de la carpeta db del repo, por ejemplo:
       :setvar RUTA "C:\Users\...\propi-facturacion\db"

   Al agregar un script nuevo, añadir su línea :r aquí, en el orden correcto.
   ===================================================================== */
:on error exit
:setvar RUTA "."

:r $(RUTA)\00_crear_base_datos.sql
:r $(RUTA)\01_esquemas_y_tablas.sql
:r $(RUTA)\02_catalogos_y_diccionario.sql
:r $(RUTA)\03_seguridad_cifrado.sql

:r $(RUTA)\04_triggers_auditoria.sql
:r $(RUTA)\05_procedimientos_crud.sql
:r $(RUTA)\06_procedimientos_reportes.sql
:r $(RUTA)\07_roles_logins_permisos.sql
:r $(RUTA)\09_datos_prueba.sql

-- Pendiente (REQ 009): crear 08_indices.sql y descomentar DESPUÉS de medir
-- los planes "antes" con los datos ya cargados:
-- :r $(RUTA)\08_indices.sql

PRINT '=== Despliegue completo ===';
