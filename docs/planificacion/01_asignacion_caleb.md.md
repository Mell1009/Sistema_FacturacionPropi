# 👨‍💻 Asignación de Tareas: Caleb

**Rol:** Frontend Developer & Technical Writer
**Enfoque:** Interfaz de usuario, documentación técnica, diccionario de datos y planes de contingencia.
**Carpetas de trabajo:** `/frontend`, `/docs/`

## 📌 Tareas Detalladas y Criterios de Aceptación

### 1. REQ 002 (Frontend): Aplicación Funcional
*   **Qué hacer:** Desarrollar la aplicación (en el lenguaje que prefieras: C#, Python, Java, etc.). Debe incluir:
    *   Pantalla de Login.
    *   CRUD de Clientes (mostrando datos desencriptados).
    *   CRUD de Productos/Servicios.
    *   Registro de Facturas (con su detalle).
    *   Registro de Notas de Crédito/Débito.
    *   Pantalla de Reportes (los 4 reportes del REQ 007).
*   **Criterio de Aceptación:** El profe pedirá abrir la app, loguearse con `propi_digitador`, insertar un cliente, y luego intentar borrarlo (lo cual debe fallar o el botón debe estar oculto). **Regla de oro:** El frontend NO debe tener strings de SQL concatenados; debe llamar a los SPs de Yamell (ej. `EXEC app.usp_Cliente_Insertar @param1...`).

### 2. REQ 001 (Docs): Modelo Entidad-Relación
*   **Qué hacer:** Generar un PDF con el grafo relacional y el diagrama E-R.
*   **Criterio de Aceptación:** Debe mostrar las tablas: Clientes, Tipos Impuesto, Productos, Facturas, Facturas Detalle, Notas, Bitácora Acceso y Bitácora Auditoría. Debe mostrar claramente las llaves primarias (PK) y foráneas (FK).

### 3. REQ 010 (Docs): Diccionario de Datos
*   **Qué hacer:** Basado en `01_esquemas_y_tablas.sql`, crear una tabla en el documento con:
    *   **Para Tablas:** Nombre de la tabla, nombre lógico, descripción, esquema.
    *   **Para Columnas:** Nombre, tipo de dato, nulidad, valor por defecto, descripción funcional, PK, FK, Check Constraint, Unicidad.
    *   **Catálogos:** Documentar explícitamente el manejo de estados (ej. `A` = Activo, `I` = Inactivo, `S` = Suspendido).
*   **Criterio de Aceptación:** El profe abrirá el script `01` y comparará 5 columnas al azar con tu documento; deben coincidir exactamente.

### 4. REQ 011, 012 y 013 (Docs): Políticas del Negocio
*   **REQ 011 (BCP - Continuidad):** Redactar: Análisis de Impacto (RTO, RPO, Priorización), Estructura de respuesta a emergencias (equipos de crisis), Estrategias de recuperación, Plan de comunicación, Mantenimiento y Capacitación.
*   **REQ 012 (Seguridad):** Redactar: Clasificación de datos (qué datos son sensibles: cédula, correo, teléfono), Seguridad en reposo (explicar el cifrado AES-256 de Yamell), Seguridad en tránsito (explicar uso de VPN, TLS, certificados), Ciclo de vida de identidades, Monitoreo y auditoría.
*   **REQ 013 (DRP - Respaldos):** Redactar: RTO/RPO, Inventario de activos, Estrategia de respaldos (Full, Diferencial, Logs), Procedimiento paso a paso de recuperación (ej. `RESTORE DATABASE...`), Equipo de recuperación y Pruebas.
*   **Criterio de Aceptación:** El documento debe tener portada (nombre app, versión, fecha, integrantes), tabla de contenidos, control de versiones, glosario e introducción.

---

## 📝 Guía de Commits para Caleb
*   `git commit -m "feat(frontend): login y CRUDs base funcionales"`
*   `git commit -m "docs(req-001): diagrama entidad-relacion y modelo relacional adjunto"`
*   `git commit -m "docs(req-010): diccionario de datos completo con catalogos"`
*   `git commit -m "docs(req-011-013): redaccion de politicas BCP, seguridad y DRP"`