# Estándar ABAP LATAM — Referencia para desarrollo

**Fuente:** `Estándar de Desarrollos SAP S/4 v1.0` (Grupo LATAM Airlines, 17/08/2024)  
**Aplicación:** Todo código ABAP generado para el clonador de empleados SAP S/4HANA y desarrollos relacionados.

---

## Convenciones de nombres

### Programas y reportes

Formato: `Z<FrenteFuncional><Modulo><TipoPrograma>_<NumCorrelativo>`

| Pos | Valor | Ejemplo clonador HR |
|-----|-------|---------------------|
| 1 | `Z` | Z |
| 2 | Frente funcional (Anexo 1) | `H` = Recursos Humanos |
| 3 | Módulo (Anexo 2) | `HR` |
| 4 | Tipo: B=Batch, C=Call trans, L=Include, M=Menú, R=Report, I=Interfaz, F=Form, D=Desarrollo, U=Funciones | `D` |
| 5 | `_` | _ |
| 6 | Correlativo 000–999 | `001` |

**Ejemplo:** `ZHHRD_001` — reporte/programa principal del clonador.

### Includes

Sufijos: `_TOP`, `_SEL`, `_F00`–`_F99`, `_CLA`, `_FORM`

### Transacciones

Formato: `Z<Frente><Modulo>T_<NNN>` → Ejemplo: `ZHHRT_001`

### Grupos de funciones

Formato: `Z<Frente><Modulo>_<NNN>` → Ejemplo: `ZHHR_001`

### Funciones

Formato: `Z<Frente><Modulo>_<TEXTO_DESCRIPTIVO>` → Ejemplo: `ZHHR_CLONE_EMPLOYEE`

### Tablas / estructuras / DDIC

| Objeto | Formato | Ejemplo |
|--------|---------|---------|
| Tabla | `Z<Modulo>_<Sufijo>` | `ZHR_CLN_CONFIG` |
| Campo | `<Ambito>_<Sufijo>` | `FCH_INGRESO`, `NMR_PERNR` |
| Data element | `ZDE_<nombre>` | `ZDE_CLONE_ID` |
| Dominio | `ZDO_<nombre>` | `ZDO_CLN_STATUS` |
| Índice | `Z00`–`Z99` | `Z01` |
| Paquete | `Z<Modulo>[_<NNN>]` | `ZHR` o `ZHR_001` |

Ampliaciones estándar: campos cliente con prefijo `ZZ`.

### Variables (obligatorio)

| Ámbito | Tipo | Prefijo |
|--------|------|---------|
| Global | Variable | `g_` |
| Local | Variable | `l_` |
| Global | Tabla interna | `gt_` |
| Local | Tabla interna | `lt_` |
| Global | Work area | `gwa_` |
| Local | Work area | `lwa_` |
| Global | Constante | `gc_` |
| Local | Constante | `lc_` |
| Global | Field symbol | `<gfs_>` |
| Local | Field symbol | `<lfs_>` |
| Global | Tipo | `gty_` |
| Local | Tipo | `lty_` |
| Global | Clase | `gcl_` |
| Local | Clase | `lcl_` |
| Global | Objeto | `go_` |
| Local | Objeto | `lo_` |
| FORM using/changing/tables | | `pu_`, `pc_`, `pt_` |
| FM import/export/changing | | `pi_`, `pe_`, `pc_`, `pt_` |
| Métodos | | `pi_`, `pe_`, `pc_`, `pr_` |

### Selection screen

- Parámetros: `P_<campo>` (ej. `P_BUKRS`)
- Select-options: `S_<campo>` (ej. `S_PERNR`)

---

## Reglas de código (obligatorias)

1. **Pretty Printer:** sangría, conversión may/min, palabras clave en MAYÚSCULAS.
2. **Un comando por línea** (punto al final de cada sentencia).
3. **Sin textos hardcode:** usar clases de mensaje / text elements / `TEXT-xxx`.
4. **Sin `SELECT *`:** listar campos explícitamente; nunca justificar su uso.
5. **Sin UPDATE/INSERT/DELETE en tablas estándar:** usar BAPIs, `CALL TRANSACTION` o BDC.
6. **Tablas Z:** ENQUEUE/DEQUEUE, manejo de locks, considerar UoW y `COMMIT WORK`.
7. **Sin modificar programas estándar SAP** (copiar con prefijo `Z` solo con autorización).
8. **Sin breakpoints** en código transportable.
9. **Manejo de errores:** validar `SY-SUBRC` tras operaciones críticas; usar `CATCH`/`TRY`.
10. **Code Inspector (SCI)** obligatorio antes de transporte.
11. **Traducciones:** español, inglés y portugués en textos de UI.
12. **Documentación en español** en cabecera de cada objeto.

### Cabecera de programa (plantilla)

```abap
*&============================================================*
*& Report  ZHHRD_001
*&============================================================*
*& Descripción: Clonador de empleados SAP S/4HANA
*& Fecha Creación = DD.MM.AAAA
*& Creador      = <usuario>
*& Empresa      = LATAM
*&============================================================*
*& Histórico de modificaciones
*&============================================================*
*& Marca  Fecha       Autor  Descripción
*& @001   AAAA.MM.DD  XX     ...
*&============================================================*
```

### Comentarios de bloque

```abap
*--------------------------------------------------------------------*
* Búsqueda de información
*--------------------------------------------------------------------*
```

### Modificaciones

Marcar con `@NNN`, autor, fecha y motivo. No eliminar código comentado salvo respaldo previo.

---

## Seguridad (AUTHORITY-CHECK)

- Incluir `AUTHORITY-CHECK` **al inicio** de la transacción/programa.
- Mínimo: objeto `S_TCODE` + objeto funcional del proceso.
- Validar `SY-SUBRC` **inmediatamente** tras el check; si ≠ 0 → `LEAVE PROGRAM`.
- `ACTVT` nunca `*`; usar `DUMMY` solo cuando no aplique valor.
- Nunca `DUMMY` en campos de autorización importantes.
- Tablas Z: grupo de autorización válido (no `&NA&`).
- `CALL TRANSACTION`: agregar `AUTHORITY-CHECK` explícito.
- RFC críticas: `AUTHORITY-CHECK` objeto `S_RFC` + objetos del FM invocado.

---

## S/4HANA y performance

- Paradigma **Top-Down / push-down** a HANA.
- Evaluar **CDS** si: volumen alto, ≥3 tablas, ≥15 campos, o FOR ALL ENTRIES repetidos.
- Evaluar **AMDP** para procesos repetitivos en BD.
- Preferir un SELECT + tabla interna vs SELECT-ENDSELECT.
- Evitar SELECT anidados, `MOVE-CORRESPONDING`, campos fuera de llave/índice.
- Estructura de tabla interna alineada con campos del SELECT.
- Analizar con **SE30** y **ST05**.

---

## Clean Code (ABAP)

- Nombres descriptivos; evitar abreviaciones ambiguas.
- Constantes en lugar de números mágicos; preferir clases de enumeración.
- Declaraciones inline en métodos cortos; no encadenar DATA.
- Preferir `REF TO` sobre field symbols (salvo ASSIGN dinámico).
- Tablas: tipo correcto (STANDARD / SORTED / HASHED); clave explícita o `EMPTY KEY`.
- Preferir `INSERT INTO TABLE`, `LINE_EXISTS`, `READ TABLE` vs LOOP, `LOOP AT WHERE`.
- Literales con `` ` ``; plantillas `|...|` para textos compuestos.
- Booleanos: `ABAP_BOOL`, `ABAP_TRUE`/`ABAP_FALSE`, `XSDBOOL()`.

---

## ALV, archivos, correo, jobs

| Tema | Estándar |
|------|----------|
| ALV | OO con `CL_GUI_CUSTOM_CONTAINER`; en batch usar `CL_GUI_DOCKING_CONTAINER` según `cl_gui_alv_grid=>offline( )` |
| Archivos front-end | `CL_GUI_FRONTEND_SERVICES` → `GUI_UPLOAD` / `GUI_DOWNLOAD` |
| Archivos Unix | `CATCH` con `CX_SY_FILE_*` |
| Correo | Clase `CL_BCS` |
| Job en fondo | `BP_START_DATE_EDITOR`; botones Diálogo/Fondo/Ver Resultados |
| Jobs duplicados | Control anti-ejecución paralela (cierres) |

---

## Restricciones absolutas

- No breakpoints en código productivo.
- No DML directo en tablas estándar.
- No `SELECT *`.
- No hardcodes (usar constantes/message class).
- Producción: DNS `sapr3ascs.cl.lan.com` para WS/FTP (no nodo directo).

---

## Anexos de nomenclatura LATAM

**Frentes funcionales:** P=Producción, F=Finanzas, G=Gestión, **H=Recursos Humanos**, C=CRM

**Módulos:** FI, **HR**, MM, SD, AP, AR, AM, SL, CO, XX, BP

---

## CDS / DDL / DCL (si aplica)

| Tipo | Formato |
|------|---------|
| CDS | `Z<Modulo>_CDS_<NNNN>` |
| DDL | `Z<Modulo>_DDL_<NNNN>` |
| DCL | `Z<Modulo>_DCL_<NNNN>` |
