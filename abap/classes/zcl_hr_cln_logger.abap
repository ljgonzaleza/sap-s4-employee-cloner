*&============================================================*
*& Class ZCL_HR_CLN_LOGGER
*&============================================================*
*& Descripción: Logger estructurado para el clonador de       *
*& empleados SAP S/4HANA                                       *
*& Fecha Creación = 10.06.2026                              *
*& Creador      = LATAM Development Team                    *
*& Empresa      = LATAM                                     *
*&============================================================*
*& Histórico de modificaciones                              *
*&============================================================*
*& Marca  Fecha       Autor  Descripción                      *
*& @001   2026.06.10  —     Versión inicial                  *
*&============================================================*

CLASS zcl_hr_cln_logger DEFINITION CREATE PUBLIC.

  PUBLIC SECTION.

    " Constantes de estado
    CONSTANTS:
      gc_status_success TYPE char1 VALUE 'S',
      gc_status_warning TYPE char1 VALUE 'W',
      gc_status_error   TYPE char1 VALUE 'E',
      gc_status_info    TYPE char1 VALUE 'I'.

    " Tipo estructura log
    TYPES:
      BEGIN OF gty_log_entry,
        log_id    TYPE sysuuid_x16,
        pernr_src TYPE pernr_d,
        pernr_tgt TYPE pernr_d,
        infty     TYPE infty,
        subty     TYPE subty,
        seqnr     TYPE seqnr,
        begda     TYPE begda,
        endda     TYPE endda,
        status    TYPE char1,
        message   TYPE string,
        uname     TYPE uname,
        datum     TYPE datum,
        uzeit     TYPE uzeit,
        clone_id  TYPE sysuuid_x16,
      END OF gty_log_entry.

    TYPES: gtt_log_entries TYPE STANDARD TABLE OF gty_log_entry.

    " Constructor
    METHODS constructor
      IMPORTING
        iv_log_object TYPE balobj_d DEFAULT 'ZHR_CLN'.

    " Iniciar sesión de log
    METHODS start_session
      IMPORTING
        iv_clone_id TYPE sysuuid_x16 OPTIONAL.

    " Finalizar sesión de log
    METHODS end_session
      IMPORTING
        iv_save TYPE abap_bool DEFAULT abap_true.

    " Loguear éxito
    METHODS log_success
      IMPORTING
        iv_pernr_src TYPE pernr_d OPTIONAL
        iv_pernr_tgt TYPE pernr_d OPTIONAL
        iv_infty     TYPE infty OPTIONAL
        iv_subty     TYPE subty OPTIONAL
        iv_seqnr     TYPE seqnr OPTIONAL
        iv_msg       TYPE string.

    " Loguear advertencia
    METHODS log_warning
      IMPORTING
        iv_pernr_src TYPE pernr_d OPTIONAL
        iv_pernr_tgt TYPE pernr_d OPTIONAL
        iv_infty     TYPE infty OPTIONAL
        iv_subty     TYPE subty OPTIONAL
        iv_seqnr     TYPE seqnr OPTIONAL
        iv_msg       TYPE string.

    " Loguear error
    METHODS log_error
      IMPORTING
        iv_pernr_src TYPE pernr_d OPTIONAL
        iv_pernr_tgt TYPE pernr_d OPTIONAL
        iv_infty     TYPE infty OPTIONAL
        iv_subty     TYPE subty OPTIONAL
        iv_seqnr     TYPE seqnr OPTIONAL
        iv_msg       TYPE string.

    " Guardar log en base de datos
    METHODS save_to_database.

    " Obtener entradas de log
    METHODS get_log_entries
      RETURNING
        VALUE(rt_entries) TYPE gtt_log_entries.

    " Mostrar log en ALV
    METHODS display_log_alv.

    " Exportar log a tabla Z
    METHODS export_to_table
      IMPORTING
        it_entries TYPE gtt_log_entries OPTIONAL.

  PROTECTED SECTION.

    DATA: gv_log_handle TYPE balloghndl,
          gv_log_object TYPE balobj_d,
          gt_log_entries TYPE gtt_log_entries,
          gv_clone_id   TYPE sysuuid_x16.

    METHODS add_log_entry
      IMPORTING
        iv_status  TYPE char1
        iv_msg     TYPE string
        is_context TYPE gty_log_entry OPTIONAL.

  PRIVATE SECTION.

    METHODS create_message
      IMPORTING
        iv_status TYPE char1
        iv_msg    TYPE string
      EXPORTING
        es_msg    TYPE bal_s_msg.

ENDCLASS.

CLASS zcl_hr_cln_logger IMPLEMENTATION.

*--------------------------------------------------------------------*
* Constructor
*--------------------------------------------------------------------*
  METHOD constructor.
    gv_log_object = iv_log_object.
    IF gv_clone_id IS INITIAL.
      TRY.
          gv_clone_id = cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error.
          gv_clone_id = '0000000000000000'.
      ENDTRY.
    ENDIF.
  ENDMETHOD.

*--------------------------------------------------------------------*
* Iniciar sesión de log
*--------------------------------------------------------------------*
  METHOD start_session.

    DATA: ls_log TYPE bal_s_log.

    IF iv_clone_id IS NOT INITIAL.
      gv_clone_id = iv_clone_id.
    ENDIF.

    ls_log-object    = gv_log_object.
    ls_log-subobject = 'CLONE'.
    ls_log-aldate    = sy-datum.
    ls_log-altime    = sy-uzeit.
    ls_log-aluser    = sy-uname.
    ls_log-extnumber = gv_clone_id.

    CALL FUNCTION 'BAL_LOG_CREATE'
      EXPORTING
        i_s_log                 = ls_log
      IMPORTING
        e_log_handle            = gv_log_handle
      EXCEPTIONS
        log_header_inconsistent = 1
        OTHERS                  = 2.

    IF sy-subrc <> 0.
      " Fallback: loguear a tabla interna
    ENDIF.

  ENDMETHOD.

*--------------------------------------------------------------------*
* Finalizar sesión de log
*--------------------------------------------------------------------*
  METHOD end_session.

    IF iv_save = abap_true.
      save_to_database( ).
    ENDIF.

    IF gv_log_handle IS NOT INITIAL.
      CALL FUNCTION 'BAL_LOG_REFRESH'
        EXPORTING
          i_log_handle  = gv_log_handle
        EXCEPTIONS
          log_not_found = 1
          OTHERS        = 2.
    ENDIF.

  ENDMETHOD.

*--------------------------------------------------------------------*
* Loguear éxito
*--------------------------------------------------------------------*
  METHOD log_success.

    DATA(ls_context) = VALUE gty_log_entry(
      pernr_src = iv_pernr_src
      pernr_tgt = iv_pernr_tgt
      infty     = iv_infty
      subty     = iv_subty
      seqnr     = iv_seqnr
      status    = gc_status_success
      message   = iv_msg
      uname     = sy-uname
      datum     = sy-datum
      uzeit     = sy-uzeit
      clone_id  = gv_clone_id
    ).

    add_log_entry(
      iv_status  = gc_status_success
      iv_msg     = iv_msg
      is_context = ls_context
    ).

  ENDMETHOD.

*--------------------------------------------------------------------*
* Loguear advertencia
*--------------------------------------------------------------------*
  METHOD log_warning.

    DATA(ls_context) = VALUE gty_log_entry(
      pernr_src = iv_pernr_src
      pernr_tgt = iv_pernr_tgt
      infty     = iv_infty
      subty     = iv_subty
      seqnr     = iv_seqnr
      status    = gc_status_warning
      message   = iv_msg
      uname     = sy-uname
      datum     = sy-datum
      uzeit     = sy-uzeit
      clone_id  = gv_clone_id
    ).

    add_log_entry(
      iv_status  = gc_status_warning
      iv_msg     = iv_msg
      is_context = ls_context
    ).

  ENDMETHOD.

*--------------------------------------------------------------------*
* Loguear error
*--------------------------------------------------------------------*
  METHOD log_error.

    DATA(ls_context) = VALUE gty_log_entry(
      pernr_src = iv_pernr_src
      pernr_tgt = iv_pernr_tgt
      infty     = iv_infty
      subty     = iv_subty
      seqnr     = iv_seqnr
      status    = gc_status_error
      message   = iv_msg
      uname     = sy-uname
      datum     = sy-datum
      uzeit     = sy-uzeit
      clone_id  = gv_clone_id
    ).

    add_log_entry(
      iv_status  = gc_status_error
      iv_msg     = iv_msg
      is_context = ls_context
    ).

  ENDMETHOD.

*--------------------------------------------------------------------*
* Agregar entrada de log
*--------------------------------------------------------------------*
  METHOD add_log_entry.

    DATA: ls_msg TYPE bal_s_msg.

    " Agregar a tabla interna
    DATA(ls_entry) = is_context.
    TRY.
        ls_entry-log_id = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        ls_entry-log_id = '0000000000000000'.
    ENDTRY.

    APPEND ls_entry TO gt_log_entries.

    " Agregar a Application Log
    IF gv_log_handle IS NOT INITIAL.

      create_message(
        EXPORTING
          iv_status = iv_status
          iv_msg    = iv_msg
        IMPORTING
          es_msg    = ls_msg
      ).

      CALL FUNCTION 'BAL_LOG_MSG_ADD'
        EXPORTING
          i_log_handle      = gv_log_handle
          i_s_msg           = ls_msg
        EXCEPTIONS
          log_not_found     = 1
          msg_inconsistent  = 2
          log_is_full       = 3
          OTHERS            = 4.

    ENDIF.

  ENDMETHOD.

*--------------------------------------------------------------------*
* Crear mensaje para Application Log
*--------------------------------------------------------------------*
  METHOD create_message.

    es_msg-msgty = iv_status.
    es_msg-msgid = 'ZHR_CLN'.

    CASE iv_status.
      WHEN gc_status_success.
        es_msg-msgno = '001'.
      WHEN gc_status_warning.
        es_msg-msgno = '002'.
      WHEN gc_status_error.
        es_msg-msgno = '003'.
      WHEN OTHERS.
        es_msg-msgno = '000'.
    ENDCASE.

    es_msg-msgv1 = iv_msg.

  ENDMETHOD.

*--------------------------------------------------------------------*
* Guardar log en base de datos
*--------------------------------------------------------------------*
  METHOD save_to_database.

    IF gv_log_handle IS NOT INITIAL.
      CALL FUNCTION 'BAL_DB_SAVE'
        EXPORTING
          i_t_log_handle       = VALUE bal_t_logh( ( gv_log_handle ) )
        EXCEPTIONS
          log_not_found        = 1
          save_not_allowed     = 2
          numbering_error    = 3
          OTHERS               = 4.
    ENDIF.

    " También guardar en tabla Z
    export_to_table( ).

  ENDMETHOD.

*--------------------------------------------------------------------*
* Obtener entradas de log
*--------------------------------------------------------------------*
  METHOD get_log_entries.
    rt_entries = gt_log_entries.
  ENDMETHOD.

*--------------------------------------------------------------------*
* Mostrar log en ALV
*--------------------------------------------------------------------*
  METHOD display_log_alv.

    DATA: lo_alv TYPE REF TO cl_salv_table.

    TRY.
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table = lo_alv
          CHANGING
            t_table      = gt_log_entries
        ).

        lo_alv->get_functions( )->set_all( abap_true ).

        lo_alv->get_columns( )->optimize( ).

        lo_alv->display( ).

      CATCH cx_salv_msg INTO DATA(lx_msg).
        MESSAGE lx_msg->get_text( ) TYPE 'E'.
    ENDTRY.

  ENDMETHOD.

*--------------------------------------------------------------------*
* Exportar log a tabla Z
*--------------------------------------------------------------------*
  METHOD export_to_table.

    DATA: lt_entries TYPE gtt_log_entries.

    IF it_entries IS SUPPLIED.
      lt_entries = it_entries.
    ELSE.
      lt_entries = gt_log_entries.
    ENDIF.

    IF lt_entries IS INITIAL.
      RETURN.
    ENDIF.

    " Convertir a formato de tabla Z
    DATA: lt_db_entries TYPE STANDARD TABLE OF zhr_cln_log.

    lt_db_entries = VALUE #(
      FOR ls_entry IN lt_entries
      ( CORRESPONDING #( ls_entry ) )
    ).

    " Insertar en base de datos
    INSERT zhr_cln_log FROM TABLE lt_db_entries.

    IF sy-subrc <> 0.
      " Manejar error si es necesario
    ENDIF.

  ENDMETHOD.

ENDCLASS.