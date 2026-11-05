/* =====================================================================
   Proyecto : Sistema de Gestión de Facturación Propi
   Script   : 03_seguridad_cifrado.sql
   Propósito: Infraestructura de Cell-Level Encryption (REQ 006):
              Database Master Key -> Certificado -> Clave simétrica AES-256.
   Idempotente.

   IMPORTANTE (trabajo en equipo con BD local)
     - La master key y el certificado se generan EN CADA MÁQUINA, por lo
       que los datos cifrados de un equipo NO se pueden descifrar en el otro.
       Los datos de prueba deben insertarse con los procedimientos/scripts
       (que cifran con la clave local), nunca restaurando backups ajenos.
     - La contraseña de abajo es SOLO de desarrollo. En producción debe
       vivir en un gestor de secretos (documentar en REQ 012).
     - Respaldar el certificado es obligatorio para poder restaurar la BD
       en otro servidor (documentar en REQ 013). Ver bloque comentado al final.

   Uso desde los procedimientos almacenados:
       OPEN SYMMETRIC KEY sk_Propi_Datos DECRYPTION BY CERTIFICATE cert_Propi_Datos;
       ... ENCRYPTBYKEY(KEY_GUID(N'sk_Propi_Datos'), CONVERT(VARCHAR(150), @valor)) ...
       ... CONVERT(VARCHAR(150), DECRYPTBYKEY(columna_cif)) ...
       CLOSE SYMMETRIC KEY sk_Propi_Datos;
   Mantener los valores a cifrar en VARCHAR(<=150) para que quepan en
   VARBINARY(256); el correo (VARBINARY(512)) admite hasta ~250 caracteres.
   ===================================================================== */
USE PropiFacturacion;
GO
SET NOCOUNT ON;
GO

-- 1) Database Master Key
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = N'##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = N'Dev_Propi#2026_CambiarEnProduccion!';
    PRINT 'Master key creada.';
END
GO

-- 2) Certificado que protege la clave simétrica
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'cert_Propi_Datos')
BEGIN
    CREATE CERTIFICATE cert_Propi_Datos
        WITH SUBJECT     = N'Propi - cifrado columnar de datos sensibles',
             EXPIRY_DATE = '20361231';
    PRINT 'Certificado creado.';
END
GO

-- 3) Clave simétrica AES-256
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = N'sk_Propi_Datos')
BEGIN
    CREATE SYMMETRIC KEY sk_Propi_Datos
        WITH ALGORITHM = AES_256
        ENCRYPTION BY CERTIFICATE cert_Propi_Datos;
    PRINT 'Clave simétrica creada.';
END
GO

-- 4) Prueba rápida de cifrado / descifrado (debe mostrar el texto original)
OPEN SYMMETRIC KEY sk_Propi_Datos DECRYPTION BY CERTIFICATE cert_Propi_Datos;

DECLARE @cifrado VARBINARY(256) =
        ENCRYPTBYKEY(KEY_GUID(N'sk_Propi_Datos'), CONVERT(VARCHAR(150), '1-0234-0567'));

SELECT  @cifrado                                          AS valor_cifrado,
        CONVERT(VARCHAR(150), DECRYPTBYKEY(@cifrado))     AS valor_descifrado;

CLOSE SYMMETRIC KEY sk_Propi_Datos;
GO

/* ---------------------------------------------------------------------
   Respaldo del certificado (ejecutar manualmente, NO subir los archivos a Git)
   ---------------------------------------------------------------------
   BACKUP CERTIFICATE cert_Propi_Datos
       TO FILE = 'C:\respaldos_seguros\cert_Propi_Datos.cer'
       WITH PRIVATE KEY (
           FILE = 'C:\respaldos_seguros\cert_Propi_Datos.pvk',
           ENCRYPTION BY PASSWORD = 'OtraClaveFuerte#2026');
   --------------------------------------------------------------------- */

PRINT '03_seguridad_cifrado.sql finalizado.';
GO
