# INFORME TÉCNICO: PROPUESTA ARQUITECTÓNICA Y MODELADO DEL SISTEMA DE GESTIÓN ACADÉMICA (SGA)

---

## 1. INTRODUCCIÓN Y DESCRIPCIÓN DEL PROBLEMA

Actualmente, la institución de educación superior gestiona la información de sus programas, estudiantes, docentes, matrículas y calificaciones mediante archivos independientes y aplicaciones aisladas. Esta fragmentación genera:
* **Duplicidad de datos** e inconsistencias en la información académica.
* **Demoras en la consulta** y reporte de resultados.
* **Falta de trazabilidad y auditoría** sobre cambios en calificaciones y matrículas.
* **Riesgos de seguridad y pérdida de información** por la ausencia de un control de accesos unificado y respaldos automatizados.

Para solucionar esta problemática, se propone el diseño arquitectónico de un **Sistema de Gestión Académica (SGA)** centralizado, accesible desde navegadores web, escalable, seguro y mantenible.

---

## 2. OBJETIVOS

### Objetivo General
Diseñar la arquitectura de software y el modelado conceptual de un Sistema de Gestión Académica (SGA) web para una institución de educación superior, garantizando altos estándares de seguridad, mantenibilidad, disponibilidad y escalabilidad.

### Objetivos Específicos
1. Clasificar y analizar los requerimientos funcionales (RF) y no funcionales (RNF) del sistema.
2. Definir y justificar el estilo arquitectónico más adecuado para el contexto institucional.
3. Elaborar los modelos UML del sistema (Casos de Uso, Componentes, Despliegue, Datos y Secuencia).
4. Construir la matriz de trazabilidad que correlacione los requerimientos con la arquitectura y sus métodos de validación.
5. Identificar riesgos, puntos únicos de falla (SPOF) y documentar las decisiones de arquitectura (ADR).

---

## 3. ALCANCE, ACTORES, SUPUESTOS Y RESTRICCIONES

### Alcance
El proyecto abarca el diseño arquitectónico, lógico, de datos y de despliegue del SGA, contemplando la autenticación, control de acceso por roles, gestión de oferta académica, matrículas, registro y consulta de calificaciones, generación de reportes y auditoría del sistema. **No incluye** la implementación del código fuente completo en producción.

### Actores del Sistema
* **Administrador:** Gestiona usuarios (docentes, estudiantes), roles, parámetros globales del sistema y consulta registros de auditoría.
* **Coordinador Académico:** Crea programas, planes de estudio, asignaturas, periodos académicos, grupos, cupos y asignación docente.
* **Docente:** Consulta grupos asignados, horarios y registra/actualiza calificaciones de sus estudiantes.
* **Estudiante:** Realiza la matrícula académica, consulta su horario y visualiza sus calificaciones.

### Supuestos
* La institución cuenta con infraestructura en la nube (AWS/Azure/GCP) o servidores propios con capacidad de virtualización y contenedores.
* Los usuarios disponen de dispositivos con acceso a internet y navegadores web modernos (Chrome, Firefox, Edge, Safari).

### Restricciones
* El presupuesto institucional sugiere optimizar costos en la fase inicial, evitando sobre-ingeniería de microservicios si no se justifica.
* Capacidad de soporte inicial para un escenario de referencia de **300 usuarios concurrentes** y tiempo de respuesta < 3 segundos en el 95 % de las peticiones.
* Cumplimiento estricto de HTTPS y cifrado de datos sensibles.

---

## 4. ANÁLISIS DE REQUERIMIENTOS

### Reglas de Negocio Clave
1. **RN-01 (Matrícula Única):** Un estudiante no puede matricularse dos veces en la misma asignatura dentro del mismo periodo académico.
2. **RN-02 (Control de Cupos):** La matrícula en un grupo solo se confirma si existen cupos disponibles. La operación debe ser atómica (transaccional).
3. **RN-03 (Edición de Notas):** Un docente solo puede modificar calificaciones en los grupos asignados a su carga dentro del periodo académico activo.
4. **RN-04 (Inmutabilidad de Auditoría):** Los registros de auditoría (logs) son de solo lectura y no pueden ser alterados ni eliminados por ningún usuario.

---

## 5. DESCRIPCIÓN Y JUSTIFICACIÓN DE LA ARQUITECTURA

### Estilo Arquitectónico Seleccionado: **Monolito Modular Basado en Capas Integrado mediante API REST**

Se descarta una arquitectura de microservicios puros debido a la complejidad operativa innecesaria que introduce para la carga proyectada (300 usuarios concurrentes). En su lugar, se adopta una **Arquitectura en Capas Internas dividida por Módulos (Monolito Modular)** con separación entre Frontend Web (SPA) y Backend (REST API).

+-------------------------------------------------------------------+
|               CAPA DE PRESENTACIÓN (Single Page App - SPA)        |
+-------------------------------------------------------------------+
|  HTTPS / REST / JSON
+-------------------------------------------------------------------+
|               CAPA DE APLICACIÓN / API GATEWAY / REVERSE PROXY   |
+-------------------------------------------------------------------+
|  [Módulo Auth & Roles]  |  [Módulo Académico]  |  [Módulo Matrículas] |
|  [Módulo Calificaciones]|  [Módulo Reportes]   |  [Módulo Auditoría] |
+-------------------------------------------------------------------+
|  ORM / SQL Transactions
+-------------------------------------------------------------------+
|               CAPA DE DATOS (PostgreSQL Relacional + Redis Cache) |
+-------------------------------------------------------------------+


### Justificación de la Selección (Atributos de Calidad):
* **Mantenibilidad (RNF-05):** La separación modular dentro del backend (paquetes independientes para Auth, Matrículas, Calificaciones) permite alta cohesión y bajo acoplamiento. Probar y modificar un módulo no interfiere con los demás.
* **Rendimiento (RNF-02) y Escalabilidad (RNF-04):** Permite escalamiento horizontal empaquetando el backend en contenedores Docker gestionados tras un balanceador de carga. La inclusión de una capa de caché (Redis) garantiza respuestas < 3 segundos.
* **Integridad y Consistencia (RNF-07):** Una base de datos relacional (como PostgreSQL) garantiza propiedades **ACID** (Atomicidad, Consistencia, Aislamiento, Durabilidad), indispensables en los procesos de matrícula concurrente y asignación de cupos.

---

## 6. MODELO DEL SISTEMA (ENTREGABLES OBLIGATORIOS)

### 6.1 Modelo de Casos de Uso

#### Descripción de Casos de Uso Principales

##### UC-07: Registrar/Modificar Calificaciones
* **Actor Principal:** Docente.
* **Precondición:** El docente ha iniciado sesión y pertenece al grupo del periodo académico activo.
* **Flujo Principal:**
  1. El docente selecciona la asignatura y el grupo asignado.
  2. El sistema despliega la lista de estudiantes matriculados.
  3. El docente ingresa o edita la nota y hace clic en "Guardar".
  4. El sistema valida el rango numérico (ej. 0.0 a 5.0).
  5. El sistema guarda la calificación en la base de datos de manera transaccional.
  6. El sistema genera un registro automático en el módulo de auditoría (RF-12).
* **Postcondición:** Calificación actualizada y evento auditado.

##### UC-08: Matricular Asignaturas
* **Actor Principal:** Estudiante.
* **Precondición:** Estudiante con sesión activa y periodo académico abierto para matrículas.
* **Flujo Principal:**
  1. El estudiante selecciona las asignaturas y grupos ofertados.
  2. El sistema verifica la disponibilidad de cupos en el grupo seleccionado.
  3. El sistema valida que el estudiante no esté ya matriculado en la misma asignatura (RN-01).
  4. El sistema registra la matrícula y descuenta el cupo disponible de forma atómica.
* **Flujo Alterno (Sin Cupo):** El sistema notifica que el grupo no tiene cupos y bloquea la confirmación.

---

### 6.2 Modelo de Componentes (Vista Lógica)

El backend se organiza lógicamente en los siguientes módulos desacoplados:

* **Authentication & Authorization Component:** Gestiona emisión de tokens JWT, hash de contraseñas (BCrypt) y validación de permisos por rol (RF-01, RF-02, RNF-01).
* **Academic Management Component:** Administra programas, asignaturas, planes de estudio, grupos y docentes (RF-03, RF-04, RF-05, RF-06).
* **Enrollment Component (Matrículas):** Contiene la lógica de negocio para validar requisitos, evitar duplicidad y reservar cupos (RF-07, RNF-07).
* **Grading Component (Calificaciones):** Gestiona el ingreso y consulta de notas (RF-08, RF-09).
* **Reporting Component:** Genera reportes optimizados en PDF/Excel mediante consultas de solo lectura (RF-10).
* **Audit Logger Component:** Captura eventos de manera asíncrona para no penalizar la latencia del usuario (RF-12, RNF-10).

---

### 6.3 Modelo de Despliegue

La solución se despliega en una arquitectura de 3 capas aisladas mediante red privada:

[Cliente Web (Navegador)]
|
| HTTPS (Puerto 443)
v
+-------------------------------------------------------------------+
| DMZ / CAPA PÚBLICA                                                |
| Balanceador de Carga (NGINX / AWS ALB) - Certificado SSL/TLS      |
+-------------------------------------------------------------------+
|
| HTTP Interno (Red Privada / VPC)
v
+-------------------------------------------------------------------+
| CAPA DE APLICACIÓN (Red Privada)                                  |
| Contenedores Docker (Node.js / Spring Boot / Python FastApi)      |
| [ Instancia Backend 1 ]         [ Instancia Backend 2 ]           |
+-------------------------------------------------------------------+
|                                       |
| TCP / Redis Protocol                  | SQL / Port 5432
v                                       v
+---------------------------------------+ +-------------------------+
| CAPA DE DATOS (Red Privada)           | | CAPA DE DATOS           |
| Redis Cache (Sesiones y Cupos)        | | PostgreSQL (Master/Repl)|
+---------------------------------------+ +-------------------------+


---

### 6.4 Modelo de Datos Conceptual

+------------------+         1..N +--------------------+
|     USUARIO      |--------------|     ROL_USUARIO    |
+------------------+              +--------------------+
| id_usuario (PK)  |                        | N
| email            |                        | 1
| password_hash    |              +--------------------+
| estado           |              |        ROL         |
+------------------+              +--------------------+
| 1                        | id_rol (PK)        |
|                          | nombre_rol         |
+------------------+       +--------------------+
|                  |
| 1                | 1
+------------------+ +--------------------+
|    ESTUDIANTE    | |      DOCENTE       |
+------------------+ +--------------------+
| id_estudiante(PK)| | id_docente (PK)    |
| id_usuario (FK)  | | id_usuario (FK)    |
| codigo_est       | | especialidad       |
+------------------+ +--------------------+
| 1                    | 1
|                      |
| N                    | N
+------------------------------------------------------+
|                      MATRÍCULA                       |
+------------------------------------------------------+
| id_matricula (PK)                                    |
| id_estudiante (FK)                                   |
| id_grupo (FK)                                        |
| fecha_matricula                                      |
+------------------------------------------------------+
| 1
|
| N
+------------------------------------------------------+
|                     CALIFICACIÓN                     |
+------------------------------------------------------+
| id_calificacion (PK)                                 |
| id_matricula (FK)                                    |
| valor_nota                                           |
| fecha_registro                                       |
+------------------------------------------------------+

       +--------------------+ 1      N +--------------------+
       |      PROGRAMA      |---------|     ASIGNATURA     |
       +--------------------+         +--------------------+
       | id_programa (PK)   |         | id_asignatura (PK) |
       | nombre             |         | id_programa (FK)   |
       +--------------------+         | creditos, nivel    |
                                      +--------------------+
                                                | 1
                                                |
                                                | N
       +--------------------+ 1      N +--------------------+
       | PERIODO_ACADEMICO  |---------|        GRUPO       |
       +--------------------+         +--------------------+
       | id_periodo (PK)    |         | id_grupo (PK)      |
       | nombre, estado     |         | id_asignatura (FK) |
       +--------------------+         | id_docente (FK)    |
                                      | cupo_max, horario  |
                                      +--------------------+

---

### 6.5 Vista de Secuencia: Proceso Crítico de Matrícula Académica

Estudiante          Navegador (SPA)          API Backend          Redis / DB (PostgreSQL)
|                      |                      |                          |
|--- 1. Selecciona --->|                      |                          |
|    grupo y confirma  |                      |                          |
|                      |--- 2. POST /matricula|                          |
|                      |    (Bearer Token) -->|                          |
|                      |                      |--- 3. Valida Token JWT ->|
|                      |                      |    y Permisos (Rol)      |
|                      |                      |                          |
|                      |                      |--- 4. BEGIN TRANSACTION ->|
|                      |                      |--- 5. SELECT FOR UPDATE -| (Bloqueo de fila
|                      |                      |    (Verifica cupos) ---->|  evita Data Race)
|                      |                      |                          |
|                      |                      |<-- 6. Cupo disponible ---|
|                      |                      |                          |
|                      |                      |--- 7. INSERT Matricula ->|
|                      |                      |--- 8. UPDATE Grupo cupo->|
|                      |                      |--- 9. COMMIT TRANSACTION>|
|                      |                      |                          |
|                      |                      |--- 10. Async Audit Log ->| (Registra evento)
|                      |<-- 11. 201 Created---|                          |
|<-- 12. Confirmación--|    (Matrícula OK)    |                          |


---

## 7. MATRIZ DE TRAZABILIDAD DE REQUERIMIENTOS

| ID Requerimiento | Nombre / Descripción | Componente / Decisión de Arquitectura | Método de Validación / Evidencia |
| :--- | :--- | :--- | :--- |
| **RF-01 / RNF-01** | Autenticación y HTTPS | Mod. Auth / BCrypt + JWT / NGINX TLS 1.3 | Prueba de penetración, análisis SAST (OWASP ZAP), inspección de headers SSL. |
| **RF-02 / RNF-11** | Roles, Permisos y Privacidad | RBAC Middleware (Role-Based Access Control) | Pruebas unitarias y de integración sobre endpoints restringidos por rol. |
| **RF-07 / RNF-07** | Matrícula y Consistencia | Mod. Matrículas / Transacciones SQL `SERIALIZABLE` | Pruebas de carga concurrente con JMeter/K6 simulando matrículas simultáneas al mismo grupo. |
| **RF-08 / RF-12** | Calificaciones y Auditoría | Mod. Calificaciones + Audit Logger Component | Inspección de la tabla `audit_logs` tras registrar notas; verificar que la acción quedó registrada. |
| **RNF-02** | Rendimiento (300 conc. < 3s) | Balanceador NGINX + Cache Redis + Pool BD | Ejecución de prueba de estrés con 300 virtual users (VUs) continuos usando K6. |
| **RNF-03 / RNF-04**| Disponibilidad 99.5% y Escalabilidad | Nodos backend redundantes en Docker + Healthchecks | Prueba de conmutación por error (*failover*): apagar una instancia y verificar disponibilidad. |
| **RNF-09** | Respaldo y Recuperación | Cron Jobs de Copias de Seguridad + Replica BD | Simulación de restauración de base de datos desde un snapshot de respaldo. |

---

## 8. DECISIONES ARQUITECTÓNICAS (ADR) Y ANÁLISIS DE RIESGOS

### Registro de Decisiones de Arquitectura (ADR)

* **ADR-01: Uso de Tokens JWT para Autenticación Stateless**
  * *Contexto:* Se requiere autenticar a 300 usuarios concurrentes sin recargar la base de datos central en cada petición.
  * *Decisión:* Emplear JSON Web Tokens (JWT) firmados digitalmente.
  * *Consecuencia:* Reduce lecturas a la base de datos para validar sesión; requiere invalidación mediante lista negra en Redis si se revoca un acceso antes del vencimiento.

* **ADR-02: Base de Datos Relacional (PostgreSQL) sobre NoSQL**
  * *Contexto:* Transacciones críticas en matrículas donde dos estudiantes compiten por el último cupo.
  * *Decisión:* Seleccionar PostgreSQL por su cumplimiento ACID riguroso y soporte de bloqueos explícitos (`SELECT FOR UPDATE`).
  * *Consecuencia:* Mayor consistencia en datos; requiere estructuración estricta de esquemas mediante migraciones.

* **ADR-03: Procesamiento Asíncrono de Auditoría (Audit Log)**
  * *Contexto:* El registro de auditoría no debe penalizar el tiempo de respuesta al usuario final (RNF-02).
  * *Decisión:* Los eventos de auditoría se envían a una cola/worker en segundo plano de manera asíncrona.
  * *Consecuencia:* El usuario recibe respuesta inmediata; si el worker falla, debe existir un mecanismo de reintento para garantizar la inmutabilidad de los registros.

### Análisis de Riesgos y Puntos Únicos de Falla (SPOF)

1. **Riesgo: Condición de Carrera (*Race Condition*) en Matrículas:**
   * *Mitigación:* Implementación de aislamiento de transacciones en la base de datos y reservas temporales de cupo atómicas en Redis.
2. **SPOF: Base de Datos Centralizada:**
   * *Mitigación:* Configuración de un nodo PostgreSQL Principal (Escritura) y una Réplica de Lectura (Read Replica) con conmutación automática.
3. **Riesgo de Seguridad: Exposición de Datos Personales:**
   * *Mitigación:* Cifrado de datos en reposo (AES-256) y en tránsito (TLS 1.3), sumado a filtrado de campos sensibles en la capa de serialización de la API REST.

---

## 9. EVIDENCIAS DEL USO DE GOOGLE AI STUDIO

### Resumen de Prompts y Ajustes Realizados:

* **Prompt 1 (Ideación de Arquitectura):** *"Propón una arquitectura web para un SGA institucional enfocado en 300 usuarios concurrentes."*
  * *Resultado de IA:* Sugirió microservicios desplegados en Kubernetes.
  * *Ajuste del estudiante:* **Modificado/Descartado por sobre-ingeniería.** Se optó por una arquitectura monolítica modular en contenedores, justificando una reducción en la complejidad operativa y menor costo de mantenimiento.
* **Prompt 2 (Modelo de Datos):** *"Genera una estructura de base de datos relacional para usuarios, roles, materias y matrículas."*
  * *Resultado de IA:* Entregó las entidades principales sin contemplar la entidad intermedia de `Grupo` ni el historial de `PeriodoAcadémico`.
  * *Ajuste del estudiante:* **Aceptado parcialmente.** Se añadieron las entidades de soporte para soportar la ofertabilidad por periodo y grupos independientes.

---

## 10. RECURSOS ADICIONALES (ENLACES DE ENTREGABLES)

* **Enlace al Repositorio (GitHub):** https://github.com/CamilaMedrano7/Prueba
* **Enlace al Video / Pitch en YouTube:** `[Insertar Enlace de YouTube Aquí]`

---

## 11. CONCLUSIONES Y RECOMENDACIONES

* La elección de una arquitectura **Monolito Modular** estructurada en capas y expuesta a través de APIs REST representa el balance óptimo entre complejidad de desarrollo, costo de infraestructura y cumplimiento de los requerimientos funcionales y no funcionales.
* La consistencia ACID de PostgreSQL y el control de transacciones previenen errores críticos durante el proceso masivo de matrículas, garantizando la integridad de la oferta académica.
* Se recomienda implementar pruebas de carga continuas en entornos de *Staging* antes del inicio de cada periodo lectivo para asegurar que el balanceador y la capa de caché respondan eficientemente ante los picos de uso.

---

## 12. REFERENCIAS BIBLIOGRÁFICAS (APA 7.ª Edición)

* Bass, L., Clements, P., & Kazman, R. (2021). *Software Architecture in Practice* (4th ed.). Addison-Wesley Professional.
* Fowler, M. (2018). *Patterns of Enterprise Application Architecture*. Addison-Wesley.
* Kleppmann, M. (2017). *Designing Data-Intensive Applications: The Big Ideas Behind Reliable, Scalable, and Maintainable Systems*. O'Reilly Media.
* OWASP Foundation. (2021). *OWASP Top Ten Web Application Security Risks*. https://owasp.org/www-project-top-ten/
