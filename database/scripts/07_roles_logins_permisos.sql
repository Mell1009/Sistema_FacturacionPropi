/* =====================================================================
   Proyecto : Sistema de Gestión de Facturación Propi
   Script   : 07_roles_logins_permisos.sql
   Propósito: Seguridad por roles (REQ 003, 004 y 008):
              roles -> logins/usuarios de prueba -> GRANT / REVOKE / DENY.
   Idempotente.

   Modelo
     rol_administrador : acceso total a la información (lectura/escritura a
                         fact y seg, lectura de aud) y a todos los procedimientos.
     rol_digitador     : ingreso de clientes, facturas y notas. Sin borrados,
                         sin catálogos, sin reportes de seguridad/auditoría.
     rol_consulta      : solo reportería (4 reportes).
   Los usuarios NO tienen acceso a tablas: solo EXECUTE sobre procedimientos
   (el encadenamiento de propiedad dbo permite que los procedimientos lean/escriban).
   La bitácora de auditoría es de solo inserción para TODOS (DENY a nivel de rol
   + trigger INSTEAD OF en 04); los triggers insertan por encadenamiento.

   REQUISITOS
     - La instancia debe estar en modo de autenticación mixto (SQL + Windows)
       para que los logins SQL puedan conectarse.
     - Las contraseñas de abajo son SOLO de desarrollo (documentar en REQ 012).
   ===================================================================== */
USE PropiFacturacion;
GO
SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   1) Roles de base de datos
   --------------------------------------------------------------------- */
IF DATABASE_PRINCIPAL_ID(N'rol_administrador') IS NULL CREATE ROLE rol_administrador AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'rol_digitador')     IS NULL CREATE ROLE rol_digitador     AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'rol_consulta')      IS NULL CREATE ROLE rol_consulta      AUTHORIZATION dbo;
GO

/* ---------------------------------------------------------------------
   2) Logins (servidor) y usuarios (base de datos) de prueba
   --------------------------------------------------------------------- */
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'propi_admin')
    CREATE LOGIN propi_admin      WITH PASSWORD = N'Propi_Admin#2026!',      CHECK_POLICY = ON, CHECK_EXPIRATION = OFF, DEFAULT_DATABASE = PropiFacturacion;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'propi_digitador')
    CREATE LOGIN propi_digitador  WITH PASSWORD = N'Propi_Digitador#2026!',  CHECK_POLICY = ON, CHECK_EXPIRATION = OFF, DEFAULT_DATABASE = PropiFacturacion;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'propi_consulta')
    CREATE LOGIN propi_consulta   WITH PASSWORD = N'Propi_Consulta#2026!',   CHECK_POLICY = ON, CHECK_EXPIRATION = OFF, DEFAULT_DATABASE = PropiFacturacion;
GO

USE PropiFacturacion;
GO
IF DATABASE_PRINCIPAL_ID(N'propi_admin')     IS NULL CREATE USER propi_admin     FOR LOGIN propi_admin;
IF DATABASE_PRINCIPAL_ID(N'propi_digitador') IS NULL CREATE USER propi_digitador FOR LOGIN propi_digitador;
IF DATABASE_PRINCIPAL_ID(N'propi_consulta')  IS NULL CREATE USER propi_consulta  FOR LOGIN propi_consulta;
GO

IF IS_ROLEMEMBER(N'rol_administrador', N'propi_admin')     = 0 ALTER ROLE rol_administrador ADD MEMBER propi_admin;
IF IS_ROLEMEMBER(N'rol_digitador',     N'propi_digitador') = 0 ALTER ROLE rol_digitador     ADD MEMBER propi_digitador;
IF IS_ROLEMEMBER(N'rol_consulta',      N'propi_consulta')  = 0 ALTER ROLE rol_consulta      ADD MEMBER propi_consulta;
GO

/* ---------------------------------------------------------------------
   3) rol_administrador : acceso total
   --------------------------------------------------------------------- */
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::fact TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::seg  TO rol_administrador;
GRANT SELECT                         ON SCHEMA::aud  TO rol_administrador;
GRANT EXECUTE                        ON SCHEMA::app  TO rol_administrador;
GRANT EXECUTE ON TYPE::app.TD_FacturaDetalle TO rol_administrador;
-- La bitácora de auditoría no se puede alterar ni por el administrador
DENY INSERT, UPDATE, DELETE ON SCHEMA::aud TO rol_administrador;
GO

/* ---------------------------------------------------------------------
   4) rol_digitador y rol_consulta : cero acceso directo a tablas
      (REVOKE limpia concesiones previas; DENY lo deja explícito)
   --------------------------------------------------------------------- */
REVOKE SELECT, INSERT, UPDATE, DELETE ON SCHEMA::fact FROM rol_digitador, rol_consulta;
REVOKE SELECT, INSERT, UPDATE, DELETE ON SCHEMA::seg  FROM rol_digitador, rol_consulta;
REVOKE SELECT, INSERT, UPDATE, DELETE ON SCHEMA::aud  FROM rol_digitador, rol_consulta;

DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::fact TO rol_digitador, rol_consulta;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::seg  TO rol_digitador, rol_consulta;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::aud  TO rol_digitador, rol_consulta;
GO

/* ---------------------------------------------------------------------
   5) rol_digitador : clientes, facturas y notas (sin borrados)
   --------------------------------------------------------------------- */
-- Sesión
GRANT EXECUTE ON app.usp_Acceso_Registrar TO rol_digitador;
GRANT EXECUTE ON app.usp_Acceso_Cerrar    TO rol_digitador;
-- Catálogos (solo lectura, para llenar combos y buscar productos)
GRANT EXECUTE ON app.usp_TipoIdentificacion_Listar TO rol_digitador;
GRANT EXECUTE ON app.usp_TipoImpuesto_Listar       TO rol_digitador;
GRANT EXECUTE ON app.usp_Producto_Listar           TO rol_digitador;
GRANT EXECUTE ON app.usp_Producto_Obtener          TO rol_digitador;
-- Clientes
GRANT EXECUTE ON app.usp_Cliente_Insertar   TO rol_digitador;
GRANT EXECUTE ON app.usp_Cliente_Actualizar TO rol_digitador;
GRANT EXECUTE ON app.usp_Cliente_Obtener    TO rol_digitador;
GRANT EXECUTE ON app.usp_Cliente_Listar     TO rol_digitador;
-- Facturas
GRANT EXECUTE ON app.usp_Factura_Insertar TO rol_digitador;
GRANT EXECUTE ON app.usp_Factura_Obtener  TO rol_digitador;
GRANT EXECUTE ON app.usp_Factura_Listar   TO rol_digitador;
GRANT EXECUTE ON TYPE::app.TD_FacturaDetalle TO rol_digitador;
-- Notas
GRANT EXECUTE ON app.usp_Nota_Insertar TO rol_digitador;
GRANT EXECUTE ON app.usp_Nota_Listar   TO rol_digitador;
-- Prohibiciones explícitas (DENY gana sobre cualquier GRANT heredado)
DENY EXECUTE ON app.usp_Cliente_Eliminar      TO rol_digitador;
DENY EXECUTE ON app.usp_Cliente_CambiarEstado TO rol_digitador;
DENY EXECUTE ON app.usp_Factura_Eliminar      TO rol_digitador;
DENY EXECUTE ON app.usp_Nota_Eliminar         TO rol_digitador;
DENY EXECUTE ON app.usp_Reporte_PistasAuditoria         TO rol_digitador;
DENY EXECUTE ON app.usp_Reporte_ConfiguracionSeguridad  TO rol_digitador;
GO

/* ---------------------------------------------------------------------
   6) rol_consulta : solo reportería
      (decisión: los 4 reportes; si se prefiere ocultar los de seguridad
       y auditoría, basta con un REVOKE sobre esos dos procedimientos)
   --------------------------------------------------------------------- */
GRANT EXECUTE ON app.usp_Acceso_Registrar TO rol_consulta;
GRANT EXECUTE ON app.usp_Acceso_Cerrar    TO rol_consulta;
GRANT EXECUTE ON app.usp_Reporte_ClientesResumido        TO rol_consulta;
GRANT EXECUTE ON app.usp_Reporte_Facturas                TO rol_consulta;
GRANT EXECUTE ON app.usp_Reporte_PistasAuditoria         TO rol_consulta;
GRANT EXECUTE ON app.usp_Reporte_ConfiguracionSeguridad  TO rol_consulta;
GO

PRINT '07_roles_logins_permisos.sql finalizado.';
GO
