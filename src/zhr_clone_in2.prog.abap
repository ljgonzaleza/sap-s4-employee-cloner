*&============================================================*
*& Report ZHR_CLONE_IN2
*&============================================================*
*& Descripción: Cargador de empleados desde archivo local     *
*&              Programa de upload para clonador HR          *
*& Fecha Creación = 10.06.2026                              *
*& Creador      = LATAM Development Team                    *
*& Empresa      = LATAM                                     *
*&============================================================*
*& Histórico de modificaciones                              *
*&============================================================*
*& Marca  Fecha       Autor  Descripción                      *
*& @001   2026.06.10  —     Versión inicial                  *
*&============================================================*

REPORT zhr_clone_in2 MESSAGE-ID zhr_cln.

*--------------------------------------------------------------------*
* Tipos
*--------------------------------------------------------------------*
TYPES:
  BEGIN OF gty_upload_result,
    pernr      TYPE pernr_d,
    status     TYPE char1,
    message    TYPE string,
    records_ok TYPE i,
    records_er TYPE i,
  END OF gty_upload_result.

*--------------------------------------------------------------------*
* Variables globales
*--------------------------------------------------------------------*
DATA:
  gt_results      TYPE STANDARD TABLE OF gty_upload_result,
  go_orchestrator TYPE REF TO zcl_hr_upl_orchestrator.

*--------------------------------------------------------------------*
* Pantalla de selección
*--------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-001.
  PARAMETERS:
    p_path   TYPE localfile OBLIGATORY,
    p_format TYPE char4 DEFAULT 'XLSX'.
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-002.
  PARAMETERS: p_mode TYPE char1 DEFAULT 'R'.
  SELECTION-SCREEN COMMENT /1(30) TEXT-m01.
  SELECTION-SCREEN COMMENT /1(30) TEXT-m02.
  SELECTION-SCREEN COMMENT /1(30) TEXT-m03.
SELECTION-SCREEN END OF BLOCK b02.

SELECTION-SCREEN BEGIN OF BLOCK b03 WITH FRAME TITLE TEXT-003.
  PARAMETERS:
    p_simul  AS CHECKBOX DEFAULT 'X',
    p_deltm  AS CHECKBOX DEFAULT 'X',
    p_commit TYPE numc3 DEFAULT '10',
    p_stop   AS CHECKBOX DEFAULT ''.
SELECTION-SCREEN END OF BLOCK b03.

*--------------------------------------------------------------------*
* START-OF-SELECTION
*--------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM validate_input.
  PERFORM execute_upload.
  PERFORM display_results.

*&--------------------------------------------------------------------*
*&      Form  VALIDATE_INPUT
*&--------------------------------------------------------------------*
FORM validate_input.

  DATA: lv_file_exists TYPE abap_bool.

  AUTHORITY-CHECK OBJECT 'ZHR_UPL'
    ID 'ACTVT' FIELD COND #( WHEN p_simul = abap_true THEN '02' ELSE '01' ).

  IF sy-subrc <> 0.
    MESSAGE e000(zhr_cln) WITH 'Sin autorización para upload'.
    LEAVE PROGRAM.
  ENDIF.

  cl_gui_frontend_services=>file_exist(
    EXPORTING
      file                 = p_path
    RECEIVING
      result               = lv_file_exists
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      wrong_parameter      = 3
      not_supported_by_gui = 4
      OTHERS               = 5
  ).

  IF lv_file_exists = abap_false.
    MESSAGE e000(zhr_cln) WITH 'El archivo no existe en la ruta especificada'.
  ENDIF.

  IF p_format NOT IN ('XLSX', 'CSV').
    MESSAGE e000(zhr_cln) WITH 'Formato debe ser XLSX o CSV'.
  ENDIF.

  IF p_mode NOT IN ('N', 'R', 'M').
    MESSAGE e000(zhr_cln) WITH 'Modo inválido: use N (Nuevos), R (Reemplazar) o M (Merge)'.
  ENDIF.

  IF p_mode = 'R' AND p_simul = abap_false.
    DATA(lv_answer) = '1'.
    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar              = 'Confirmación Requerida'
        text_question         = 'Modo REEMPLAZAR borrará todos los datos existentes. ¿Continuar?'
        text_button_1         = 'Sí'
        text_button_2         = 'No'
        default_button        = '2'
        display_cancel_button = ' '
      IMPORTING
        answer                = lv_answer
      EXCEPTIONS
        text_not_found        = 1
        OTHERS                = 2.

    IF lv_answer <> '1'.
      MESSAGE i000(zhr_cln) WITH 'Operación cancelada por usuario'.
      LEAVE PROGRAM.
    ENDIF.
  ENDIF.

ENDFORM.

*&--------------------------------------------------------------------*
*&      Form  EXECUTE_UPLOAD
*&--------------------------------------------------------------------*
FORM execute_upload.

  DATA(ls_params) = VALUE zcl_hr_upl_orchestrator=>gty_params(
    path          = p_path
    format        = p_format
    mode          = p_mode
    simulation    = p_simul
    del_tm        = p_deltm
    commit_size   = p_commit
    stop_on_error = p_stop
  ).

  go_orchestrator = NEW zcl_hr_upl_orchestrator( ).

  go_orchestrator->execute(
    EXPORTING is_params  = ls_params
    IMPORTING et_results = gt_results
  ).

  DATA(lv_total) = lines( gt_results ).
  DATA(lv_ok)    = lines( FILTER #( gt_results WHERE status = 'S' ) ).
  DATA(lv_err)   = lines( FILTER #( gt_results WHERE status = 'E' ) ).

  MESSAGE s001(zhr_cln) WITH lv_total lv_ok lv_err.

ENDFORM.

*&--------------------------------------------------------------------*
*&      Form  DISPLAY_RESULTS
*&--------------------------------------------------------------------*
FORM display_results.

  DATA: lo_alv TYPE REF TO cl_salv_table.

  IF gt_results IS INITIAL.
    MESSAGE i000(zhr_cln) WITH 'No hay resultados para mostrar'.
    RETURN.
  ENDIF.

  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING  t_table      = gt_results
      ).
      lo_alv->get_functions( )->set_all( abap_true ).
      lo_alv->get_columns( )->optimize( ).
      lo_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_msg).
      MESSAGE lx_msg->get_text( ) TYPE 'E'.
  ENDTRY.

ENDFORM.

*--------------------------------------------------------------------*
* Textos (crear en SE38 → Ir a → Elementos de texto)
*--------------------------------------------------------------------*
* TEXT-001 = 'Archivo Origen'
* TEXT-002 = 'Modo de Carga'
* TEXT-003 = 'Opciones'
* TEXT-m01 = 'N = Solo Nuevos'
* TEXT-m02 = 'R = Reemplazar (Borrar + Insertar)'
* TEXT-m03 = 'M = Merge (Solo faltantes)'
*--------------------------------------------------------------------*
