# Código ABAP - Clonador de Empleados SAP S/4HANA

Este directorio contiene el código ABAP generado para el **Clonador de Empleados SAP S/4HANA** según especificación funcional v1.3.1.

## Estructura del Proyecto

```
abap/
├── ddic/                    # Objetos DDIC (Tablas, Data Elements)
├── interfaces/              # Interfaces (BAdI)
├── classes/                 # Clases ABAP OO
└── programs/              # Programas ABAP
```

## Componentes Generados

### 1. DDIC Objects (`ddic/`)

| Objeto | Tipo | Descripción |
|--------|------|-------------|
| `ZHR_CLN_CONFIG` | Tabla | Configuración global del clonador |
| `ZDE_CLN_MODE_UNIQ` | Data Element | Modo manejo campos únicos (C/L/G) |
| `ZHR_CLN_LOG` | Tabla | Log de operaciones de clonación |

### 2. Interfaces (`interfaces/`)

| Interfaz | Descripción |
|----------|-------------|
| `ZIF_HR_CLN_BADI` | BAdI para extensibilidad del clonador |

Métodos del BAdI:
- `ADJUST_SOURCE_BEFORE_COPY` - Modificar registro origen
- `ADJUST_TARGET_BEFORE_SAVE` - Modificar registro destino
- `SKIP_INFOTYPE` - Omitir infotipo según lógica custom
- `AFTER_INFOTYPE_COPY` - Post-proceso por infotipo
- `AFTER_CLONE_COMPLETE` - Workflow/notificaciones post-clonación

### 3. Clases del Clonador (`classes/`)

#### Clases Core

| Clase | Descripción |
|-------|-------------|
| `ZCL_HR_CLN_ITYPE_BASE` | Clase abstracta base para handlers de infotipos |
| `ZCL_HR_CLN_LOGGER` | Logger estructurado con Application Log y tabla Z |
| `ZCL_HR_CLN_ORCHESTRATOR` | Coordinador principal de clonación |
| `ZCL_HR_CLN_EXPORTER` | Exportación a Excel/CSV en PC local |

#### Handlers de Infotipos (Core)

| Clase | Infotipo |
|-------|----------|
| `ZCL_HR_CLN_ITYPE_0002` | 0002 - Datos Personales |

#### Clases del Upload

| Clase | Descripción |
|-------|-------------|
| `ZCL_HR_UPL_ORCHESTRATOR` | Coordinador programa de carga |
| `ZCL_HR_UPL_FILE_READER` | Lector archivos Excel/CSV desde PC |
| `ZCL_HR_UPL_PARSER` | Parser y validador de estructura |
| `ZCL_HR_UPL_REPLACER` | Lógica borrar+insertar (modo reemplazar) |
| `ZCL_HR_UPL_VALIDATOR` | Validaciones pre-carga |
| `ZCL_HR_UPL_LOGGER` | Logger específico de upload |

### 4. Programas (`programs/`)

| Programa | Transacción | Descripción |
|----------|-------------|-------------|
| `ZHR_CLONE_OUT2` | `ZHR_CLONE` | Programa exportación/clonación a archivo local |
| `ZHR_CLONE_IN2` | `ZHR_UPLOAD` | Programa carga/upload desde archivo local |

## Características Implementadas

### Programa Exportación/Clonación (ZHR_CLONE_OUT2)

- [x] Clonación de múltiples empleados en batch
- [x] Infotipos PA core (0000-0021)
- [x] Exportación a Excel (.xlsx) y CSV
- [x] Modo simulación (dry-run)
- [x] Logger estructurado con Application Log
- [x] Manejo de campos únicos (CPF, cédula, email)
- [x] Shift de fechas configurable
- [x] Extensibilidad vía BAdI

### Programa Carga/Upload (ZHR_CLONE_IN2)

- [x] Carga desde archivo Excel/CSV
- [x] Modos: NUEVOS, REEMPLAZAR, MERGE
- [x] Validación de estructura y datos
- [x] Simulación previa
- [x] Borrado de datos existentes (modo REEMPLAZAR)
- [x] Log detallado de operaciones
- [x] Commit por batch de empleados

## Estándar LATAM Aplicado

El código sigue el **Estándar de Desarrollos SAP S/4 v1.0** de Grupo LATAM Airlines:

- ✅ Nomenclatura: `Z<Frente><Modulo><Tipo>_<NNN>`
- ✅ Variables: `g_`/`l_`, tablas `gt_`/`lt_`, work areas `gwa_`/`lwa_`
- ✅ Pretty Printer: sangría, keywords MAYÚSCULAS
- ✅ Cabecera autodocumentada en español
- ✅ AUTHORITY-CHECK al inicio
- ✅ TRY/CATCH para runtime errors
- ✅ Sin SELECT *, sin textos hardcode
- ✅ Sin UPDATE/INSERT/DELETE en tablas estándar (usar BAPIs)

## Objetos Pendientes de Implementar

Para completar el desarrollo según especificación:

### Handlers de Infotipos
- `ZCL_HR_CLN_ITYPE_0000` - Acciones
- `ZCL_HR_CLN_ITYPE_0001` - Asignación Organizativa
- `ZCL_HR_CLN_ITYPE_0006` - Direcciones
- `ZCL_HR_CLN_ITYPE_0007` - Planificación Tiempos
- `ZCL_HR_CLN_ITYPE_0008` - Remuneración Básica
- `ZCL_HR_CLN_ITYPE_0009` - Datos Bancarios
- `ZCL_HR_CLN_ITYPE_0014` - Pagos Recurrentes
- `ZCL_HR_CLN_ITYPE_0015` - Pagos Adicionales
- `ZCL_HR_CLN_ITYPE_0016` - Contrato
- `ZCL_HR_CLN_ITYPE_0021` - Familiares

### Handlers Time Management
- `ZCL_HR_CLN_ITYPE_2001` - Absentismos
- `ZCL_HR_CLN_ITYPE_2006` - Quotas de Ausencia
- `ZCL_HR_CLN_ITYPE_2011` - Entradas de Horario
- `ZCL_HR_CLN_PTQUODED` - Handler tabla PTQUODED
- `ZCL_HR_CLN_TEVEN` - Handler tabla TEVEN

### Handlers Localización
- `ZCL_HR_CLN_LOC_BR` - Brasil (MOLGA 37)
- `ZCL_HR_CLN_LOC_CO` - Colombia (MOLGA 38)
- `ZCL_HR_CLN_LOC_INTL` - Estándar internacional

### Handlers Infotipos Z
- `ZCL_HR_CLN_ITYPE_9000` - Viáticos y traslados
- `ZCL_HR_CLN_ITYPE_9001` - Novedades absentismos
- `ZCL_HR_CLN_ITYPE_9002` - Licencias
- `ZCL_HR_CLN_ITYPE_9003` - Datos licencias/categorías

### Clases Upload (Detalle)
- `ZCL_HR_UPL_PARSER` - Parser completo Excel/CSV
- `ZCL_HR_UPL_PT_LOADER` - Cargador tabla PTQUODED
- `ZCL_HR_UPL_TEVEN_LOADER` - Cargador tabla TEVEN

## Próximos Pasos

1. Implementar handlers restantes de infotipos core
2. Implementar handlers Time Management (2001, 2006, 2011)
3. Implementar handlers PTQUODED y TEVEN con mapeo de claves
4. Implementar handlers de localización BR/CO
5. Implementar handlers infotipos Z (9000-9003)
6. Crear clase de parser completa para upload
7. Crear autorizaciones (SU21) y roles (PFCG)
8. Crear message class ZHR_CLN
9. Generar transporte DEV → QAS → PRD

## Notas Técnicas

### Time Management (PTQUODED y TEVEN)

La implementación debe manejar:

- **PTQUODED**: Mapeo de `QUONR` (quota) y `DOCNR` (documento ausencia)
- **TEVEN**: Generación nuevo `PDSNR` (número consecutivo)

Orden de procesamiento:
```
1. Clonar IT 2006 → obtener nuevos QUONR
2. Clonar IT 2001 → obtener nuevos DOCNR
3. Para cada PTQUODED: mapear QUONR y DOCNR a nuevos valores
```

### Validaciones Críticas

- Unicidad de `PERNR`, `ZAUSW` en TEVEN
- Existencia de `SATZA` (clase hecho temporal) en customizing
- Consistencia de fechas en IT 2001/2006/PTQUODED
- Saldos disponibles de quotas al cargar deducciones

## Documentación Relacionada

- `specs/activos/specs.md` - Especificación funcional v1.3.1
- `specs/activos/sap-abap-estandar-latam.md` - Resumen estándar LATAM
- `.cursor/rules/sap-abap-latam-standards.mdc` - Regla persistente Cursor

## Contacto

Desarrollador: LATAM Development Team
Fecha: 10.06.2026