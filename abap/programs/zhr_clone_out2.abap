*&============================================================*
*& Report ZHR_CLONE_OUT2                                      *
*&============================================================*
*& Descripción: Clonador de empleados SAP S/4HANA             *
*&              Programa principal de clonación/exportación   *
*& Fecha Creación = 10.06.2026                              *
*& Creador      = LATAM Development Team                    *
*& Empresa      = LATAM                                     *
*&============================================================*
*& Histórico de modificaciones                              *
*&============================================================*
*& Marca  Fecha       Autor  Descripción                      *
*& @001   2026.06.10  —     Versión inicial                  *
*&============================================================*

REPORT zhr_clone_out2 MESSAGE-ID zhr_cln.

*--------------------------------------------------------------------*
* DECLARACIÓN DE CLASES LOCALES
*--------------------------------------------------------------------*
CLASS lcl_application DEFINITION DEFERRED.

*--------------------------------------------------------------------*
* INCLUDE TOP
*--------------------------------------------------------------------*
INCLUDE zhr_clone_out2_top.

*--------------------------------------------------------------------*
* INCLUDE SELECTION-SCREEN
*--------------------------------------------------------------------*
INCLUDE zhr_clone_out2_sel.

*--------------------------------------------------------------------*
* INCLUDE FORMS
*--------------------------------------------------------------------*
INCLUDE zhr_clone_out2_f00.

*--------------------------------------------------------------------*
* CLASE LOCAL DE APLICACIÓN
*--------------------------------------------------------------------*
CLASS lcl_application DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS:
      main,
      validate_selection,
      execute_cloning,
      display_results.

  PRIVATE SECTION.
    CLASS-DATA:
      gt_results TYPE zcl_hr_cln_orchestrator=>gtt_results,
      go_orchestrator TYPE REF TO zcl_hr_cln_orchestrator.
ENDCLASS.

CLASS lcl_application IMPLEMENTATION.

  METHOD main.
    validate_selection( ).
    execute_cloning( ).
    display_results( ).
  ENDMETHOD.

  METHOD validate_selection.
    " Validaciones implementadas en form validate_input
  ENDMETHOD.

  METHOD execute_cloning.
    " Ejecución implementada en form execute_clone
  ENDMETHOD.

  METHOD display_results.
    " Visualización implementada en form display_alv
  ENDMETHOD.

ENDCLASS.

*--------------------------------------------------------------------*
* START-OF-SELECTION
*--------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM validate_input.
  PERFORM execute_clone.
  PERFORM display_alv.

*--------------------------------------------------------------------*
* INCLUDE TOP (Definiciones)
*--------------------------------------------------------------------*
INCLUDE zhr_clone_out2_top.

*&--------------------------------------------------------------------*
*&  Include           ZHR_CLONE_OUT2_TOP
*&--------------------------------------------------------------------*

" Tipos
TYPES:
  BEGIN OF gty_pernr_range,
    sign   TYPE sign,
    option TYPE option,
    low    TYPE pernr_d,
    high   TYPE pernr_d,
  END OF gty_pernr_range.

" Tablas
DATA:
  gt_pernr_src TYPE STANDARD TABLE OF gty_pernr_range,
  gt_results   TYPE zcl_hr_cln_orchestrator=>gtt_results.

" Objetos
DATA:
  go_orchestrator TYPE REF TO zcl_hr_cln_orchestrator.

" Variables
DATA:
  gv_export_path TYPE string,
  gv_simulation  TYPE abap_bool,
  gv_error_flag  TYPE abap_bool.

*--------------------------------------------------------------------*
* INCLUDE SELECTION-SCREEN
*--------------------------------------------------------------------*
INCLUDE zhr_clone_out2_sel.

*&--------------------------------------------------------------------*
*&  Include           ZHR_CLONE_OUT2_SEL
*&--------------------------------------------------------------------*

" Selección de empleados origen
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS: s_pernr FOR pernr-pernr OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b01.

" Selección de destino
SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-002.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(25) TEXT-p01.
    PARAMETERS: p_mode TYPE char1 DEFAULT 'A'.
  SELECTION-SCREEN END OF LINE.

  SELECT-OPTIONS: s_ptgt FOR pernr-pernr NO INTERVALS.

  PARAMETERS:
    p_bukrs TYPE bukrs,
    p_werks TYPE persa,
    p_btrtl TYPE btrtl.
SELECTION-SCREEN END OF BLOCK b02.

" Opciones de clonación
SELECTION-SCREEN BEGIN OF BLOCK b03 WITH FRAME TITLE TEXT-003.
  PARAMETERS:
    p_hist  AS CHECKBOX DEFAULT '',
    p_simul AS CHECKBOX DEFAULT 'X',
    p_overw AS CHECKBOX DEFAULT '',
    p_shift TYPE i DEFAULT 0.
SELECTION-SCREEN END OF BLOCK b03.

" Rango de infotipos
SELECTION-SCREEN BEGIN OF BLOCK b04 WITH FRAME TITLE TEXT-004.
  PARAMETERS:
    p_ifrom TYPE infty DEFAULT '0000',
    p_ito   TYPE infty DEFAULT '9999',
    p_ctry  TYPE land1.
SELECTION-SCREEN END OF BLOCK b04.

" Time Management
SELECTION-SCREEN BEGIN OF BLOCK b05 WITH FRAME TITLE TEXT-005.
  PARAMETERS: p_incltm AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b05.

" Exportación local
SELECTION-SCREEN BEGIN OF BLOCK b06 WITH FRAME TITLE TEXT-006.
  PARAMETERS:
    p_exp    AS CHECKBOX DEFAULT '',
    p_format TYPE char4 DEFAULT 'XLSX',
    p_split  AS CHECKBOX DEFAULT ''.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(20) TEXT-p02.
    PARAMETERS: p_path TYPE localfile.
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b06.

*--------------------------------------------------------------------*
* INCLUDE FORMS
*--------------------------------------------------------------------*
INCLUDE zhr_clone_out2_f00.

*&--------------------------------------------------------------------*
*&  Include           ZHR_CLONE_OUT2_F00
*&--------------------------------------------------------------------*

*&--------------------------------------------------------------------*
*&      Form  VALIDATE_INPUT
*&--------------------------------------------------------------------*
FORM validate_input.

  DATA: lv_subrc TYPE sysubrc.

  " Verificar autorización para S_TCODE
  AUTHORITY-CHECK OBJECT 'S_TCODE'
    ID 'TCD' FIELD sy-tcode.

  IF sy-subrc <> 0.
    MESSAGE e000(zhr_cln) WITH 'Sin autorización para transacción'.
    LEAVE PROGRAM.
  ENDIF.

  " Verificar que hay PERNR seleccionados
  IF s_pernr[] IS INITIAL.
    MESSAGE e000(zhr_cln) WITH 'Debe seleccionar al menos un PERNR origen'.
  ENDIF.

  " Verificar formato de exportación
  IF p_exp = abap_true.
    IF p_format NOT IN ('XLSX', 'CSV', 'JSON').
      MESSAGE e000(zhr_cln) WITH 'Formato de exportación inválido'.
    ENDIF.
  ENDIF.

  " Validar shift de fechas
  IF p_shift < -365 OR p_shift > 365.
    MESSAGE e000(zhr_cln) WITH 'Shift de fechas debe estar entre -365 y 365 días'.
  ENDIF.

ENDFORM.

*&--------------------------------------------------------------------*
*&      Form  EXECUTE_CLONE
*&--------------------------------------------------------------------*
FORM execute_clone.

  DATA: ls_params TYPE zcl_hr_cln_orchestrator=>gty_params.

  " Preparar parámetros
  ls_params = VALUE #(
    pernr_src    = s_pernr[]
    pernr_tgt    = s_ptgt[]
    bukrs        = p_bukrs
    werks        = p_werks
    btrtl        = p_btrtl
    copy_hist    = p_hist
    simulation   = p_simul
    overwrite    = p_overw
    date_shift   = p_shift
    itype_from   = p_ifrom
    itype_to     = p_ito
    country      = p_ctry
    incl_tm      = p_incltm
    export_local = p_exp
    exp_format   = p_format
    exp_path     = p_path
    exp_split    = p_split
  ).

  " Crear orquestador
  go_orchestrator = NEW zcl_hr_cln_orchestrator( ).

  " Ejecutar clonación
  go_orchestrator->execute(
    EXPORTING
      is_params      = ls_params
    IMPORTING
      et_results     = gt_results
      ev_export_path = gv_export_path
  ).

  " Verificar errores
  LOOP AT gt_results TRANSPORTING NO FIELDS
    WHERE status = 'E'.
    gv_error_flag = abap_true.
    EXIT;
  ENDLOOP.

  " Mensaje resumen
  DATA(lv_total) = lines( gt_results );
  DATA(lv_ok)    = lines( FILTER #( gt_results WHERE status = 'S' ) );
  DATA(lv_err)   = lines( FILTER #( gt_results WHERE status = 'E' ) );

  MESSAGE s001(zhr_cln) WITH lv_total lv_ok lv_err.

ENDFORM.

*&--------------------------------------------------------------------*
*&      Form  DISPLAY_ALV
*&--------------------------------------------------------------------*
FORM display_alv.

  DATA: lo_alv    TYPE REF TO cl_salv_table,
        lo_events TYPE REF TO cl_salv_events_table.

  IF gt_results IS INITIAL.
    MESSAGE i000(zhr_cln) WITH 'No hay resultados para mostrar'.
    RETURN.
  ENDIF.

  TRY.
      " Crear ALV
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = lo_alv
        CHANGING
          t_table      = gt_results
      );

      " Configurar funciones
      lo_alv->get_functions( )->set_all( abap_true ).

      " Configurar columnas
      DATA(lo_cols) = lo_alv->get_columns( );
      lo_cols->optimize( );

      " Configurar colores según status
      DATA(lo_col) = lo_cols->get_column( 'STATUS' );
      IF lo_col IS BOUND.
        lo_col->set_color( VALUE #( col = 1 ) );
      ENDIF.

      " Configurar eventos
      lo_events = lo_alv->get_event( );
      SET HANDLER on_user_command FOR lo_events.

      " Mostrar
      lo_alv->display( );

    CATCH cx_salv_msg INTO DATA(lx_msg).
      MESSAGE lx_msg->get_text( ) TYPE 'E'.
  ENDTRY.

ENDFORM.

*&--------------------------------------------------------------------*
*&      Form  ON_USER_COMMAND
*&--------------------------------------------------------------------*
FORM on_user_command USING iv_ucomm TYPE salv_de_function.

  CASE iv_ucomm.
    WHEN 'LOG'.
      " Mostrar log detallado
      PERFORM show_log.
    WHEN 'EXPORT'.
      " Exportar nuevamente
      PERFORM re_export.
    WHEN OTHERS.
      " Otros comandos
  ENDCASE.

ENDFORM.

*&--------------------------------------------------------------------*
*&      Form  SHOW_LOG
*&--------------------------------------------------------------------*
FORM show_log.

  DATA: lo_logger TYPE REF TO zcl_hr_cln_logger.

  lo_logger = NEW zcl_hr_cln_logger( );
  lo_logger->display_log_alv( );

ENDFORM.

*&--------------------------------------------------------------------*
*&      Form  RE_EXPORT
*&--------------------------------------------------------------------*
FORM re_export.

  DATA: lo_exporter TYPE REF TO zcl_hr_cln_exporter,
        lv_path     TYPE string.

  lo_exporter = NEW zcl_hr_cln_exporter( );

  lo_exporter->export_to_file(
    EXPORTING
      it_results   = gt_results
      iv_format    = p_format
      iv_path      = p_path
    IMPORTING
      ev_file_path = lv_path
  );

  IF lv_path IS NOT INITIAL.
    MESSAGE s000(zhr_cln) WITH 'Exportado a: ' lv_path.
  ENDIF.

ENDFORM.

*--------------------------------------------------------------------*
* Textos (para crear en SE51 con textos 001-006, p01-p02)
*--------------------------------------------------------------------*
* TEXT-001 = 'Empleados Origen'
* TEXT-002 = 'Destino'
* TEXT-003 = 'Opciones de Clonación'
* TEXT-004 = 'Rango de Infotipos'
* TEXT-005 = 'Time Management'
* TEXT-006 = 'Exportación Local'
* TEXT-p01 = 'Modo:'
* TEXT-p02 = 'Ruta:'
*--------------------------------------------------------------------*