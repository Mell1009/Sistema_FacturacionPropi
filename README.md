# 🧾 Sistema de Gestión de Facturación — Propi

Proyecto final · IF-0010 Bases de Datos II · UCR, Recinto de Paraíso (G22)
Base de datos: **SQL Server 2022** · Nombre de la BD: **`PropiFacturacion`**

Este repositorio guarda la base de datos **como código**: son scripts `.sql` numerados. Cada integrante tiene su **propia instancia local** de SQL Server y construye la BD ejecutando los mismos scripts. **Nunca se suben** archivos `.mdf`, `.ldf` ni `.bak`.

---

## 📑 Contenido

1. [Qué necesitas](#1-qué-necesitas)
2. [Instalación en Windows (camino principal)](#2-instalación-en-windows-camino-principal)
3. [Instalación en Mac / Linux (con Docker)](#3-instalación-en-mac--linux-con-docker)
4. [Descargar el proyecto](#4-descargar-el-proyecto)
5. [Desplegar la base de datos](#5-desplegar-la-base-de-datos)
6. [Verificar que quedó bien](#6-verificar-que-quedó-bien)
7. [Usuarios de prueba](#7-usuarios-de-prueba)
8. [Día a día: bajar cambios y volver a desplegar](#8-día-a-día-bajar-cambios-y-volver-a-desplegar)
9. [Empezar de cero](#9-empezar-de-cero)
10. [Problemas comunes](#10-problemas-comunes)
11. [Qué hace cada script](#11-qué-hace-cada-script)
12. [Reglas del repo](#12-reglas-del-repo)

---

## 1. Qué necesitas

| Herramienta | Para qué | Notas |
|---|---|---|
| **SQL Server 2022** edición **Developer** | El motor de base de datos | Gratis. Evita *Express*: no sirve para la réplica del REQ 014 |
| **SSMS** (SQL Server Management Studio) | Ver tablas, ejecutar consultas | Solo Windows. En Mac/Linux se puede usar *Azure Data Studio* o la extensión *SQL Server (mssql)* de VS Code |
| **sqlcmd** | Ejecutar los scripts desde terminal | Viene con SQL Server; en Mac/Linux se instala aparte |
| **Git** | Bajar y subir cambios | https://git-scm.com |

Requisitos del equipo: ~2 GB libres en disco y 4 GB de RAM para el motor (8 GB en total es lo cómodo).

---

## 2. Instalación en Windows (camino principal)

### 2.1 Instalar SQL Server 2022 Developer

1. Descarga **SQL Server 2022 Developer** desde la página oficial de Microsoft.
2. Ejecuta el instalador y elige **Básica** o **Personalizada** (cualquiera sirve).
3. Si eliges *Personalizada*, en **Database Engine Configuration** marca **Mixed Mode (SQL Server authentication and Windows authentication)** y define una contraseña para `sa`.
   > ⚠️ **Mixed Mode es obligatorio.** Los usuarios de la aplicación (`propi_admin`, `propi_digitador`, `propi_consulta`) son *logins de SQL Server*. Sin este modo no podrán conectarse.
4. Si usaste la instalación *Básica*, activa el modo mixto después (ver 2.3).

### 2.2 Instalar SSMS

Descarga **SQL Server Management Studio** y instálalo con el asistente.

### 2.3 Activar modo de autenticación mixto (si no lo hiciste al instalar)

1. Abre **SSMS** y conéctate a tu instancia con **Windows Authentication**.
2. Clic derecho sobre el servidor → **Properties** → **Security**.
3. Marca **SQL Server and Windows Authentication mode** → **OK**.
4. Clic derecho sobre el servidor → **Restart** (confirma).

### 2.4 Averiguar el nombre de tu instancia

Abre **PowerShell** y ejecuta:

```powershell
Get-Service MSSQL*
```

| Servicio que ves | Nombre de servidor que usarás (`-S`) |
|---|---|
| `MSSQLSERVER` | `localhost` |
| `MSSQL$SQLEXPRESS` | `.\SQLEXPRESS` |
| `MSSQL$NOMBRE` | `.\NOMBRE` |

> En esta guía usamos `localhost`. Si tu instancia es otra, cámbialo en todos los comandos.

### 2.5 Comprobar que `sqlcmd` funciona

```powershell
sqlcmd -S localhost -E -C -Q "SELECT @@VERSION"
```

Debe imprimir la versión de SQL Server. Si dice que `sqlcmd` no se reconoce, cierra y abre PowerShell; si sigue igual, instala *sqlcmd* con `winget install sqlcmd` o las *Command Line Utilities* de Microsoft.

### 2.6 Comprobar el modo mixto

```powershell
sqlcmd -S localhost -E -C -Q "SELECT SERVERPROPERTY('IsIntegratedSecurityOnly') AS solo_windows"
```

Debe devolver **`0`**. Si devuelve `1`, repite el paso 2.3.

> 🔎 **Sobre las banderas de `sqlcmd`:**
> `-S` servidor · `-E` usa tu usuario de Windows · `-C` confía en el certificado del servidor (necesario en local con las versiones nuevas) · `-b` aborta si hay error · `-f 65001` lee los archivos como UTF-8 (tildes y ñ) · `-i` archivo a ejecutar · `-Q` consulta directa.

---

## 3. Instalación en Mac / Linux (con Docker)

SQL Server no corre de forma nativa en Mac. La salida es Docker.

### 3.1 Instalar lo necesario

- **Docker Desktop** (o Docker Engine en Linux).
- **Git**.
- **sqlcmd** (la versión moderna, multiplataforma):
  - Mac: `brew install sqlcmd`
  - Linux / Windows: `winget install sqlcmd` o ver https://learn.microsoft.com/sql/tools/sqlcmd/go-sqlcmd-utility
- *(Apple Silicon)* En Docker Desktop activa **Settings → General → "Use Rosetta for x86_64/amd64 emulation"**.

### 3.2 Levantar SQL Server

```bash
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=Propi_Sa#2026!" \
  -p 1433:1433 --name propi-sql -d mcr.microsoft.com/mssql/server:2022-latest
```

- Ya viene en modo mixto.
- Espera unos 20 segundos y prueba:

```bash
sqlcmd -S localhost -U sa -P 'Propi_Sa#2026!' -C -Q "SELECT @@VERSION"
```

- Para detenerlo / volver a encenderlo: `docker stop propi-sql` / `docker start propi-sql`.
- Los datos viven dentro del contenedor. Si lo borras (`docker rm`), pierdes la BD (se recrea con los scripts).

> En Docker **no existe** autenticación de Windows (`-E`). En todos los comandos de esta guía usa en su lugar: `-U sa -P 'Propi_Sa#2026!'`.

---

## 4. Descargar el proyecto

```bash
git clone <URL-DEL-REPOSITORIO>
cd <nombre-de-la-carpeta-del-repo>
```

> Si ya lo tenías clonado: `git pull`.

Abre la terminal **dentro de la carpeta que contiene `run_all.sql`**. Todos los comandos siguientes se ejecutan desde ahí, porque `run_all.sql` busca los demás scripts en su misma carpeta.

---

## 5. Desplegar la base de datos

### Opción A — Terminal, Windows (recomendada ✅)

En PowerShell, dentro de la carpeta de los scripts:

```powershell
sqlcmd -S localhost -E -C -b -f 65001 -i run_all.sql
```

### Opción B — Terminal, Mac / Linux / Docker

`run_all.sql` usa rutas con `\` (estilo Windows), así que en Mac/Linux es más seguro ejecutar los scripts uno por uno, en orden:

```bash
for f in [0-9]*.sql; do
  echo "▶ $f"
  sqlcmd -S localhost -U sa -P 'Propi_Sa#2026!' -C -b -f 65001 -i "$f" || break
done
```

El `[0-9]*.sql` toma los scripts numerados en orden alfabético y se detiene al primer error.

### Opción C — Desde SSMS

1. Abre `run_all.sql` en SSMS.
2. Menú **Query → SQLCMD Mode** (debe quedar activo).
3. Cambia esta línea por la ruta absoluta de **tu** carpeta (sin tocarla en Git, solo en tu pantalla):
   ```
   :setvar RUTA "C:\Users\TU_USUARIO\...\carpeta-de-scripts"
   ```
4. Presiona **F5**.

### ¿Qué debería ver al terminar?

Mensajes `... finalizado.` por cada script y al final:

```
=== Despliegue completo ===
```

Antes de eso, el script de datos de prueba imprime una tabla con el número de filas por tabla.

> ⏱️ Tarda de 10 a 60 segundos, según el equipo.
> Es seguro correrlo varias veces: los scripts son **idempotentes** (no duplican ni rompen nada).

---

## 6. Verificar que quedó bien

Usa tu conexión de administrador local en `<CONEXION_ADMIN>`:

- Windows: `-S localhost -E -C`
- Docker: `-S localhost -U sa -P 'Propi_Sa#2026!' -C`

### 6.1 ¿Existe la BD y tiene datos?

```bash
sqlcmd <CONEXION_ADMIN> -d PropiFacturacion -Q "SELECT 'Clientes' AS tabla, COUNT(*) AS filas FROM fact.Cliente UNION ALL SELECT 'Productos', COUNT(*) FROM fact.Producto UNION ALL SELECT 'Facturas', COUNT(*) FROM fact.Factura UNION ALL SELECT 'Lineas detalle', COUNT(*) FROM fact.FacturaDetalle UNION ALL SELECT 'Notas', COUNT(*) FROM fact.NotaCreditoDebito UNION ALL SELECT 'Bitacora acceso', COUNT(*) FROM seg.BitacoraAcceso"
```

Esperado: ~**1000** clientes, productos, facturas, notas y accesos; ~**2500** líneas de detalle.

### 6.2 ¿Están los triggers de auditoría?

```bash
sqlcmd <CONEXION_ADMIN> -d PropiFacturacion -Q "SELECT COUNT(*) AS triggers FROM sys.triggers WHERE parent_class = 1"
```

Esperado: **25** (24 de auditoría = 8 tablas × 3, más 1 que protege la bitácora para que sea de solo inserción).

### 6.3 ¿Está funcionando el cifrado?

Los datos sensibles se guardan cifrados; el procedimiento los descifra:

```bash
sqlcmd <CONEXION_ADMIN> -d PropiFacturacion -Q "SELECT TOP 1 num_identificacion_cif AS cifrado FROM fact.Cliente ORDER BY cod_cliente; EXEC app.usp_Cliente_Obtener @cod_cliente = 1"
```

Esperado: primero un valor binario ilegible (`0x00A3...`); luego el cliente con identificación, correo y teléfono **en texto normal**.

### 6.4 ¿Funcionan los usuarios y los permisos?

**Digitador** (puede ingresar, no puede borrar ni ver tablas directo):

```bash
# ✅ Debe funcionar y devolver clientes
sqlcmd -S localhost -U propi_digitador -P 'Propi_Digitador#2026!' -C -d PropiFacturacion -Q "EXEC app.usp_Acceso_Registrar; EXEC app.usp_Cliente_Listar @ind_estado = 'A'"

# ❌ Debe fallar con "permission was denied"
sqlcmd -S localhost -U propi_digitador -P 'Propi_Digitador#2026!' -C -d PropiFacturacion -Q "SELECT * FROM fact.Cliente"
sqlcmd -S localhost -U propi_digitador -P 'Propi_Digitador#2026!' -C -d PropiFacturacion -Q "EXEC app.usp_Cliente_Eliminar @cod_cliente = 1"
```

**Consulta** (solo reportes):

```bash
# ✅ Debe funcionar
sqlcmd -S localhost -U propi_consulta -P 'Propi_Consulta#2026!' -C -d PropiFacturacion -Q "EXEC app.usp_Reporte_Facturas @fec_desde = '2026-01-01', @fec_hasta = '2026-12-31'"

# ❌ Debe fallar
sqlcmd -S localhost -U propi_consulta -P 'Propi_Consulta#2026!' -C -d PropiFacturacion -Q "EXEC app.usp_Cliente_Insertar @nom_cliente='x'"
```

### 6.5 ¿Funciona la auditoría?

El digitador crea una nota; después comprobamos que quedó registrada **a su nombre**:

```bash
sqlcmd -S localhost -U propi_digitador -P 'Propi_Digitador#2026!' -C -d PropiFacturacion -Q "EXEC app.usp_Acceso_Registrar; EXEC app.usp_Nota_Insertar @num_factura = 1, @ind_tipo = 'C', @des_motivo = 'Prueba del README'"

sqlcmd -S localhost -U propi_admin -P 'Propi_Admin#2026!' -C -d PropiFacturacion -Q "SELECT TOP 1 fec_registro, ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos FROM aud.BitacoraAuditoria WHERE cod_tabla = 'fact.NotaCreditoDebito' ORDER BY fec_registro DESC"
```

Esperado: `ind_accion = I`, `cod_usuario = propi_digitador`, `cod_sesion_usuario` con un número, y `des_datos` en formato JSON.

> ℹ️ La bitácora de auditoría tendrá **miles de filas** desde el inicio: es normal, los datos de prueba también disparan los triggers.

### 6.6 ¿El reporte de seguridad lista los permisos?

```bash
sqlcmd -S localhost -U propi_admin -P 'Propi_Admin#2026!' -C -d PropiFacturacion -Q "EXEC app.usp_Reporte_ConfiguracionSeguridad"
```

Si todo lo anterior salió como se espera: **¡tu entorno está listo!** 🎉

---

## 7. Usuarios de prueba

> ⚠️ Contraseñas **solo para desarrollo**. En producción irían en un gestor de secretos (se documenta en la política de seguridad, REQ 012).

| Login / Usuario | Contraseña | Rol | Puede |
|---|---|---|---|
| `propi_admin` | `Propi_Admin#2026!` | `rol_administrador` | Todo (la bitácora de auditoría es solo lectura incluso para él) |
| `propi_digitador` | `Propi_Digitador#2026!` | `rol_digitador` | Registrar clientes, facturas y notas. **No** borra ni ve reportes de seguridad/auditoría |
| `propi_consulta` | `Propi_Consulta#2026!` | `rol_consulta` | Solo reportería |

Datos para conectar el frontend:

| Dato | Valor |
|---|---|
| Servidor | `localhost` (o tu instancia, p. ej. `.\SQLEXPRESS`) |
| Base de datos | `PropiFacturacion` |
| Autenticación | SQL Server (usuario y clave de la tabla) |
| Cifrado / certificado | En local: `TrustServerCertificate=True` |

La aplicación **solo** debe ejecutar procedimientos almacenados del esquema `app` (nunca SQL armado con texto). Al iniciar sesión llama a `app.usp_Acceso_Registrar` y al salir a `app.usp_Acceso_Cerrar`.
Mantén **una sola conexión abierta** durante la sesión, o vuelve a llamar a `usp_Acceso_Registrar` cada vez que reabras una del *pool*: si no, la auditoría pierde el identificador de sesión.

---

## 8. Día a día: bajar cambios y volver a desplegar

Cuando tu compañero sube cambios:

```bash
git pull
```

y luego repite el paso 5. Como los scripts son idempotentes, solo se aplican las diferencias (procedimientos y triggers se re-crean con `CREATE OR ALTER`).

**Pero ojo ⚠️:** si el cambio fue en la **estructura de una tabla ya existente** (agregar/cambiar columnas), el script de tablas no la modifica porque ya existe. En ese caso haz el [reinicio completo](#9-empezar-de-cero).

**Para subir tus cambios:**

```bash
git checkout -b feature/lo-que-hiciste
# ... editas scripts, los pruebas en tu BD local con el paso 5 ...
git add .
git commit -m "feat(db): descripción corta"
git push origin feature/lo-que-hiciste
```

y abres un *Pull Request* hacia `dev` para que el otro lo revise.
**Antes de subir, siempre prueba tus scripts en tu BD local.**

---

## 9. Empezar de cero

Para borrar tu BD local y recrearla limpia (**se pierden todos los datos locales**, pero los de prueba se vuelven a generar):

**Windows:**
```powershell
sqlcmd -S localhost -E -C -b -f 65001 -i reset_local.sql
sqlcmd -S localhost -E -C -b -f 65001 -i run_all.sql
```

**Mac / Linux / Docker:**
```bash
sqlcmd -S localhost -U sa -P 'Propi_Sa#2026!' -C -b -f 65001 -i reset_local.sql
# ...y vuelves a correr el bucle del paso 5, opción B
```

> `reset_local.sql` solo borra la **base de datos**. Los *logins* (`propi_*`) viven en el servidor y se conservan; el despliegue los reutiliza.
> Los datos cifrados dependen del certificado de la BD: al recrear la BD se genera un certificado nuevo y los datos de prueba se cifran de nuevo. Por eso **no se restauran backups de otra máquina**.

Si quieres reiniciar todo el contenedor Docker: `docker rm -f propi-sql` y repite el paso 3.2.

---

## 10. Problemas comunes

| Síntoma / error | Causa probable | Solución |
|---|---|---|
| `'sqlcmd' is not recognized` | No está instalado o falta reiniciar la terminal | Ver 2.5; cierra y abre PowerShell |
| `SSL Provider: certificate chain was issued by an authority that is not trusted` | Falta `-C` | Agrega `-C` al comando |
| `Login failed for user 'propi_digitador'` | Modo mixto apagado, o el despliegue no terminó | Revisa 2.6 y vuelve a correr el paso 5 |
| `Login failed for user '...'` con `-E` | Tu usuario de Windows no es administrador de SQL Server | Reinstala/agrega tu usuario como *sysadmin*; en una instalación nueva, marca "Add Current User" |
| `Cannot open server "localhost"` / `A network-related error` | Servicio apagado o instancia con otro nombre | `Get-Service MSSQL*` → inicia el servicio y ajusta `-S` (ver 2.4) |
| `Cannot open file ... run_all.sql` o `:r` no encuentra scripts | Terminal en otra carpeta | `cd` a la carpeta donde está `run_all.sql` |
| Tildes y ñ salen como `Ã¡`, `Ã±` | Falta `-f 65001` | Agrégalo al comando |
| `Sqlcmd: Error ... Incorrect syntax near ':'` (en SSMS) | Modo SQLCMD apagado | Menú **Query → SQLCMD Mode** |
| `Database 'PropiFacturacion' is in use` al reiniciar | Conexiones abiertas (SSMS, la app) | Cierra pestañas/app; `reset_local.sql` ya fuerza el cierre, pero cierra SSMS si insiste |
| `Cannot find the symmetric key / certificate` | El script de cifrado no corrió | Vuelve a correr el despliegue completo desde el inicio |
| `Msg 15466` o error del certificado al correr procedimientos | La BD se restauró desde un backup de otra máquina | No restaures backups ajenos: usa `reset_local.sql` + despliegue |
| Docker: `port is already allocated` (1433) | Otro SQL Server usa el puerto | Cambia a `-p 14330:1433` y usa `-S localhost,14330` |
| Docker en Mac: el contenedor se cierra solo | Falta emulación / poca RAM | Activa Rosetta (3.1) y dale ≥ 4 GB a Docker |
| Permisos denegados al ejecutar un procedimiento como `propi_*` | Faltó correr el script de roles/permisos | Repite el despliegue (es idempotente) |

Si algo no está aquí, copia el mensaje de error **completo** y pásalo al equipo.

---

## 11. Qué hace cada script

El orden real de ejecución lo define `run_all.sql`. Los nombres exactos de archivo pueden variar ligeramente entre versiones; lo importante es el orden.

| Paso | Contenido | REQ |
|---|---|---|
| Creación de la BD | Crea `PropiFacturacion`, modo de recuperación FULL, aislamiento por versiones | 007, 013, 014 |
| Esquemas y tablas | Esquemas `fact`, `seg`, `aud` y las 9 tablas con sus restricciones | 001 |
| Catálogos y diccionario | Datos base (tipos de identificación, impuestos) y descripciones para el diccionario de datos | 010 |
| Cifrado | *Master key*, certificado y clave simétrica AES-256 | 006 |
| Triggers de auditoría | 3 triggers (I/U/D) por tabla que alimentan la bitácora | 005 |
| Procedimientos CRUD | Login/logout, CRUDs, facturación con detalle (esquema `app`) | 002, 003 |
| Procedimientos de reportes | Los 4 reportes (clientes, facturas, auditoría, seguridad) | 007 |
| Roles, logins y permisos | `rol_administrador`, `rol_digitador`, `rol_consulta` con `GRANT`/`REVOKE`/`DENY` | 003, 004, 008 |
| Índices | *(pendiente)* clustered / nonclustered y cuadro antes/después | 009 |
| Datos de prueba | ~1,000 registros por tabla (clientes se cifran con la clave de **tu** máquina) | 009 |
| `reset_local.sql` | Elimina la BD local para empezar de cero | — |

### Esquemas de la base de datos

| Esquema | Contenido |
|---|---|
| `fact` | Negocio: clientes, tipos de impuesto, productos, facturas, detalle, notas |
| `seg` | Seguridad: bitácora de acceso (quién entró, desde dónde, cuándo) |
| `aud` | Auditoría: bitácora de cambios (solo inserción) |
| `app` | Procedimientos almacenados que usa la aplicación |

---

## 12. Reglas del repo

- ✅ Se suben: scripts `.sql`, código de la aplicación, documentos, capturas de planes de ejecución.
- ❌ **Nunca** subir: `.bak`, `.mdf`, `.ldf`, `.trn`, certificados (`.cer`, `.pvk`, `.pfx`), archivos `.env` con claves reales.
- No hacer *push* directo a `main`: trabajar en ramas `feature/*`, integrar a `dev` con *Pull Request* y revisión cruzada.
- Todo script debe poder correrse **más de una vez** sin romper nada (`IF NOT EXISTS`, `CREATE OR ALTER`).
- Al agregar un script nuevo, añadirlo también a `run_all.sql` **en el orden correcto**.
- Las contraseñas de este README son de desarrollo. No reutilizarlas en ningún otro lado.

---

*Equipo: pareja del grupo 22 · Entrega y defensa: 24 de noviembre de 2026, 16:00*
