# 👩‍💻 Asignación de Tareas: Yamell

**Rol:** Database Administrator & Backend Developer
**Enfoque:** Seguridad de BD, Triggers de auditoría, rendimiento, alta disponibilidad y lógica transaccional.
**Carpetas de trabajo:** `/database/scripts`, `/database/evidencias/`

## 📌 Tareas Detalladas y Criterios de Aceptación

### 1. REQ 003, 004 y 008 (Seguridad SQL)
*   **Qué hacer:**
    *   Crear Logins en el servidor (`propi_admin`, `propi_digitador`, `propi_consulta`).
    *   Crear Usuarios en la BD y asignarlos a Roles (`rol_administrador`, `rol_digitador`, `rol_consulta`).
    *   Configurar permisos con `GRANT` (ej. dar EXECUTE a los SPs de reportes al rol consulta), `DENY` (ej. denegar SELECT directo a tablas al digitador) y `REVOKE`.
    *   Crear los SPs `app.usp_Acceso_Registrar` y `app.usp_Acceso_Cerrar` que insertan en la tabla `seg.BitacoraAcceso` (capturando IP, terminal, etc.).
*   **Criterio de Aceptación:** Si Caleb se loguea como `propi_digitador` en el frontend y ejecuta un `SELECT * FROM fact.Cliente` directo por SSMS, debe dar error de permisos. Si ejecuta los SPs permitidos, debe funcionar.

### 2. REQ 005 (Triggers de Auditoría)
*   **Qué hacer:** En `04_triggers_auditoria.sql`, crear 3 triggers (`AFTER INSERT`, `AFTER UPDATE`, `AFTER DELETE`) para **cada una de las 8 tablas** de negocio.
    *   Deben insertar en `aud.BitacoraAuditoria`.
    *   Usar `SESSION_CONTEXT(N'usuario')` para saber quién hizo el cambio.
    *   Usar `NEWID()` para el `cod_guid`.
    *   **El reto:** En el trigger de UPDATE, el campo `des_datos` debe guardar el "ANTES" y "DESPUÉS" en formato JSON. (Investiga cómo usar las tablas virtuales `INSERTED` y `DELETED` y la cláusula `FOR JSON PATH`).
*   **Criterio de Aceptación:** El profe pedirá modificar el teléfono de un cliente y luego consultar la bitácora; debe verse el JSON con el valor viejo y el nuevo.

### 3. REQ 006 (Cifrado Columnar)
*   **Qué hacer:** En `03_seguridad_cifrado.sql`, crear la Master Key, el Certificado y la Symmetric Key (AES-256). 
    *   Modificar los SPs de Cliente para que usen `ENCRYPTBYKEY` al insertar/actualizar y `DECRYPTBYKEY` al listar los campos: identificación, teléfono y correo.
*   **Criterio de Aceptación:** Al hacer un `SELECT` directo a la tabla `fact.Cliente`, los campos sensibles deben verse como binarios (basura). Al ejecutar el SP `app.usp_Cliente_Listar`, deben verse en texto plano.

### 4. REQ 007 (SPs de Reportes)
*   **Qué hacer:** Crear 4 Procedimientos Almacenados en `06_procedimientos_reportes.sql`.
    *   **Obligatorio:** Cada SP debe tener `BEGIN TRY ... BEGIN CATCH` y `BEGIN TRANSACTION ... COMMIT/ROLLBACK`.
    *   **Isolation Level:** Debes investigar y añadir en los comentarios del código por qué usas `SET TRANSACTION ISOLATION LEVEL SNAPSHOT` o `READ COMMITTED SNAPSHOT` (para que los reportes no bloqueen las facturas nuevas).
    *   Reportes solicitados: Clientes Resumido, Facturas, Pistas de Auditoría, Configuración de Seguridad.
*   **Criterio de Aceptación:** El profe ejecutará los SPs con parámetros de fecha y usuario; deben devolver los datos exactos y no deben romperse si se le pasa una fecha nula o incorrecta.

### 5. REQ 009 (Optimización e Índices)
*   **Qué hacer:**
    *   Usar el script `09_datos_prueba.sql` para llenar las tablas (1000 registros).
    *   En SSMS, activar "Include Actual Execution Plan" y ejecutar los reportes. Guardar captura (Plan Original).
    *   Crear índices (Clustered y Non-Clustered) en un script nuevo `08_indices.sql` (ej. índice en `fec_factura`, índice en `num_identificacion`).
    *   Volver a ejecutar los reportes, guardar captura (Plan Final).
    *   Hacer un cuadro comparativo (Tiempo y Costo) en un documento o Excel.
*   **Criterio de Aceptación:** Demostrar con números y capturas que el tiempo de respuesta bajó tras crear los índices.

### 6. REQ 014 (Replicación HA/DR)
*   **Qué hacer:** 
    *   Configurar un Grupo de Disponibilidad (Always On) con un nodo secundario. Como es local, puedes usar un segundo contenedor Docker en tu máquina para simular el nodo secundario.
    *   Configurar la replicación continua para lograr RPO ≤ 60 segundos.
    *   Hacer una prueba de failover (simular caída del principal) y medir el RTO (debe ser ≤ 5 minutos).
*   **Criterio de Aceptación:** En la defensa, mostrar que si apagas el nodo principal, el secundario toma el control y no se pierden los datos insertados en el último minuto.

---

## 📝 Guía de Commits para Yamell
*   `git commit -m "feat(db): logins, roles y permisos GRANT/DENY implementados (REQ 003, 004, 008)"`
*   `git commit -m "feat(db): triggers de auditoria con JSON y SESSION_CONTEXT (REQ 005)"`
*   `git commit -m "feat(db): cifrado AES-256 para datos sensibles de clientes (REQ 006)"`
*   `git commit -m "feat(db): SPs de reportes con manejo de errores y transacciones (REQ 007)"`
*   `git commit -m "perf(db): creacion de indices y evidencias de mejora de rendimiento (REQ 009)"`
*   `git commit -m "feat(infra): configuracion Always On y pruebas de failover (REQ 014)"`