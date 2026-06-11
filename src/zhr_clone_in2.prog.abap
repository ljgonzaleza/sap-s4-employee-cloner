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
* Variables globales
*--------------------------------------------------------------------*
DATA:
  gt_results      TYPE zcl_hr_upl_orchestrator=>gtt_results,
  go_orchestrator TYPE REF TO zcl_hr_upl_orchestrator.

*--------------------------------------------------------------------*
* Pantalla de selección
*--------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-001.
  PARAMETERS:
    p_path   TYPE localfile DEFAULT 'C:\temp\Infotipos_.txt' OBLIGATORY,
    p_format TYPE char4 DEFAULT 'TXT'.
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN BEGIN OF BLOCK b04 WITH FRAME TITLE TEXT-004.
  PARAMETERS:
    p_clpath TYPE localfile DEFAULT 'C:\temp\Clusters_.txt'.
  SELECTION-SCREEN COMMENT /1(60) TEXT-c01.
SELECTION-SCREEN END OF BLOCK b04.

SELECTION-SCREEN BEGIN OF BLOCK b03 WITH FRAME TITLE TEXT-003.
  PARAMETERS:
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

  DATA: lv_file_exists TYPE abap_bool,
        lv_answer      TYPE char1.

  cl_gui_frontend_services=>file_exist(
    EXPORTING
      file                 = CONV string( p_path )
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
    MESSAGE e000(zhr_cln) WITH 'El archivo de infotipos no existe en la ruta indicada'.
  ENDIF.

  " Confirmación antes de sobreescribir datos (siempre modo Reemplazar)
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = 'Confirmación Requerida'
      text_question         = 'Se borrarán y reemplazarán los datos existentes del empleado. ¿Continuar?'
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

ENDFORM.

*&--------------------------------------------------------------------*
*&      Form  EXECUTE_UPLOAD
*&--------------------------------------------------------------------*
FORM execute_upload.

  DATA: lv_total TYPE i,
        lv_ok    TYPE i,
        lv_err   TYPE i.

  DATA(ls_params) = VALUE zcl_hr_upl_orchestrator=>gty_params(
    path           = p_path
    format         = 'TXT'
    mode           = 'R'         " Siempre Reemplazar
    simulation     = abap_false  " Siempre modo real
    del_tm         = p_deltm
    commit_size    = p_commit
    stop_on_error  = p_stop
    cluster_path   = p_clpath
  ).

  go_orchestrator = NEW zcl_hr_upl_orchestrator( ).

  go_orchestrator->execute(
    EXPORTING is_params  = ls_params
    IMPORTING et_results = gt_results
  ).

  lv_total = lines( gt_results ).

  LOOP AT gt_results INTO DATA(ls_result).
    CASE ls_result-status.
      WHEN 'S'. lv_ok  = lv_ok + 1.
      WHEN 'E'. lv_err = lv_err + 1.
    ENDCASE.
  ENDLOOP.

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
      lo_alv->get_columns( )->set_optimize( abap_true ).
      lo_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_msg).
      MESSAGE lx_msg->get_text( ) TYPE 'E'.
  ENDTRY.

ENDFORM.

*--------------------------------------------------------------------*
* Textos (crear en SE38 → Ir a → Elementos de texto)
*--------------------------------------------------------------------*
* TEXT-001 = 'Archivo Infotipos_'
* TEXT-003 = 'Opciones de Carga'
* TEXT-004 = 'Archivo Clusters_ (Opcional)'
* TEXT-c01 = 'Clusters_.txt generado por ZHR_CLONE_OUT2'
*--------------------------------------------------------------------*
