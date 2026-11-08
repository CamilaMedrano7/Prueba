CREATE TABLE usuarios (
    id_usuario SERIAL PRIMARY KEY,
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    estado VARCHAR(20) DEFAULT 'ACTIVO',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE roles (
    id_rol SERIAL PRIMARY KEY,
    nombre_rol VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE usuario_roles (
    id_usuario INT REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    id_rol INT REFERENCES roles(id_rol) ON DELETE CASCADE,
    PRIMARY KEY (id_usuario, id_rol)
);

CREATE TABLE estudiantes (
    id_estudiante SERIAL PRIMARY KEY,
    id_usuario INT UNIQUE REFERENCES usuarios(id_usuario),
    codigo_estudiante VARCHAR(20) UNIQUE NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL
);

CREATE TABLE docentes (
    id_docente SERIAL PRIMARY KEY,
    id_usuario INT UNIQUE REFERENCES usuarios(id_usuario),
    codigo_docente VARCHAR(20) UNIQUE NOT NULL,
    especialidad VARCHAR(100)
);

CREATE TABLE programas (
    id_programa SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    codigo_programa VARCHAR(20) UNIQUE NOT NULL
);

CREATE TABLE asignaturas (
    id_asignatura SERIAL PRIMARY KEY,
    id_programa INT REFERENCES programas(id_programa),
    codigo VARCHAR(20) NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    creditos INT NOT NULL,
    nivel INT NOT NULL
);

CREATE TABLE periodos_academicos (
    id_periodo SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    estado VARCHAR(20) DEFAULT 'ABIERTO'
);

CREATE TABLE grupos (
    id_grupo SERIAL PRIMARY KEY,
    id_asignatura INT REFERENCES asignaturas(id_asignatura),
    id_docente INT REFERENCES docentes(id_docente),
    id_periodo INT REFERENCES periodos_academicos(id_periodo),
    cupo_maximo INT NOT NULL,
    horario VARCHAR(100) NOT NULL
);

CREATE TABLE matriculas (
    id_matricula SERIAL PRIMARY KEY,
    id_estudiante INT REFERENCES estudiantes(id_estudiante),
    id_grupo INT REFERENCES grupos(id_grupo),
    fecha_matricula TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_estudiante_grupo UNIQUE(id_estudiante, id_grupo)
);

CREATE TABLE calificaciones (
    id_calificacion SERIAL PRIMARY KEY,
    id_matricula INT REFERENCES matriculas(id_matricula) ON DELETE CASCADE,
    valor_nota NUMERIC(3,2) CHECK (valor_nota >= 0.0 AND valor_nota <= 5.0),
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE audit_logs (
    id_log SERIAL PRIMARY KEY,
    id_usuario INT REFERENCES usuarios(id_usuario),
    accion VARCHAR(100) NOT NULL,
    tabla_afectada VARCHAR(50) NOT NULL,
    detalles TEXT,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
