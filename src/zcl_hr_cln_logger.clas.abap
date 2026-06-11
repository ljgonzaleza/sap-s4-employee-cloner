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

CLASS zcl_hr_cln_logger DEFINITION PUBLIC CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      gc_status_success TYPE char1 VALUE 'S',
      gc_status_warning TYPE char1 VALUE 'W',
      gc_status_error   TYPE char1 VALUE 'E',
      gc_status_info    TYPE char1 VALUE 'I'.

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

    TYPES: gtt_log_entries TYPE STANDARD TABLE OF gty_log_entry WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING
        iv_log_object TYPE balobj_d DEFAULT 'ZHR_CLN'.

    METHODS start_session
      IMPORTING
        iv_clone_id TYPE sysuuid_x16 OPTIONAL.

    METHODS end_session
      IMPORTING
        iv_save TYPE abap_bool DEFAULT abap_true.

    METHODS log_success
      IMPORTING
        iv_pernr_src TYPE pernr_d OPTIONAL
        iv_pernr_tgt TYPE pernr_d OPTIONAL
        iv_infty     TYPE infty OPTIONAL
        iv_subty     TYPE subty OPTIONAL
        iv_seqnr     TYPE seqnr OPTIONAL
        iv_msg       TYPE string.

    METHODS log_warning
      IMPORTING
        iv_pernr_src TYPE pernr_d OPTIONAL
        iv_pernr_tgt TYPE pernr_d OPTIONAL
        iv_infty     TYPE infty OPTIONAL
        iv_subty     TYPE subty OPTIONAL
        iv_seqnr     TYPE seqnr OPTIONAL
        iv_msg       TYPE string.

    METHODS log_error
      IMPORTING
        iv_pernr_src TYPE pernr_d OPTIONAL
        iv_pernr_tgt TYPE pernr_d OPTIONAL
        iv_infty     TYPE infty OPTIONAL
        iv_subty     TYPE subty OPTIONAL
        iv_seqnr     TYPE seqnr OPTIONAL
        iv_msg       TYPE string.

    METHODS log_info
      IMPORTING
        iv_pernr_src TYPE pernr_d OPTIONAL
        iv_pernr_tgt TYPE pernr_d OPTIONAL
        iv_msg       TYPE string.

    METHODS save_to_database.

    METHODS get_log_entries
      RETURNING
        VALUE(rt_entries) TYPE gtt_log_entries.

    METHODS display_log_alv.

    METHODS export_to_table
      IMPORTING
        it_entries TYPE gtt_log_entries OPTIONAL.

  PROTECTED SECTION.

    DATA: gv_log_handle  TYPE balloghndl,
          gv_log_object  TYPE balobj_d,
          gt_log_entries TYPE gtt_log_entries,
          gv_clone_id    TYPE sysuuid_x16.

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

  METHOD constructor.
    gv_log_object = iv_log_object.
    TRY.
        gv_clone_id = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        gv_clone_id = '0000000000000000'.
    ENDTRY.
  ENDMETHOD.

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
  ENDMETHOD.

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

  METHOD log_success.
    DATA(ls_context) = VALUE gty_log_entry(
      pernr_src = iv_pernr_src  pernr_tgt = iv_pernr_tgt
      infty = iv_infty          subty = iv_subty
      seqnr = iv_seqnr          status = gc_status_success
      message = iv_msg          uname = sy-uname
      datum = sy-datum          uzeit = sy-uzeit
      clone_id = gv_clone_id
    ).
    add_log_entry( iv_status = gc_status_success iv_msg = iv_msg is_context = ls_context ).
  ENDMETHOD.

  METHOD log_warning.
    DATA(ls_context) = VALUE gty_log_entry(
      pernr_src = iv_pernr_src  pernr_tgt = iv_pernr_tgt
      infty = iv_infty          subty = iv_subty
      seqnr = iv_seqnr          status = gc_status_warning
      message = iv_msg          uname = sy-uname
      datum = sy-datum          uzeit = sy-uzeit
      clone_id = gv_clone_id
    ).
    add_log_entry( iv_status = gc_status_warning iv_msg = iv_msg is_context = ls_context ).
  ENDMETHOD.

  METHOD log_error.
    DATA(ls_context) = VALUE gty_log_entry(
      pernr_src = iv_pernr_src  pernr_tgt = iv_pernr_tgt
      infty = iv_infty          subty = iv_subty
      seqnr = iv_seqnr          status = gc_status_error
      message = iv_msg          uname = sy-uname
      datum = sy-datum          uzeit = sy-uzeit
      clone_id = gv_clone_id
    ).
    add_log_entry( iv_status = gc_status_error iv_msg = iv_msg is_context = ls_context ).
  ENDMETHOD.

  METHOD log_info.
    DATA(ls_context) = VALUE gty_log_entry(
      pernr_src = iv_pernr_src  pernr_tgt = iv_pernr_tgt
      status = gc_status_info   message = iv_msg
      uname = sy-uname          datum = sy-datum
      uzeit = sy-uzeit          clone_id = gv_clone_id
    ).
    add_log_entry( iv_status = gc_status_info iv_msg = iv_msg is_context = ls_context ).
  ENDMETHOD.

  METHOD add_log_entry.
    DATA: ls_msg TYPE bal_s_msg.

    DATA(ls_entry) = is_context.
    TRY.
        ls_entry-log_id = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        ls_entry-log_id = '0000000000000000'.
    ENDTRY.

    APPEND ls_entry TO gt_log_entries.

    IF gv_log_handle IS NOT INITIAL.
      create_message( EXPORTING iv_status = iv_status iv_msg = iv_msg IMPORTING es_msg = ls_msg ).

      CALL FUNCTION 'BAL_LOG_MSG_ADD'
        EXPORTING
          i_log_handle     = gv_log_handle
          i_s_msg          = ls_msg
        EXCEPTIONS
          log_not_found    = 1
          msg_inconsistent = 2
          log_is_full      = 3
          OTHERS           = 4.
    ENDIF.
  ENDMETHOD.

  METHOD create_message.
    es_msg-msgty = iv_status.
    es_msg-msgid = 'ZHR_CLN'.
    es_msg-msgno = SWITCH #( iv_status
      WHEN gc_status_success THEN '001'
      WHEN gc_status_warning THEN '002'
      WHEN gc_status_error   THEN '003'
      ELSE '000' ).
    es_msg-msgv1 = iv_msg.
  ENDMETHOD.

  METHOD save_to_database.
    DATA: lt_handles TYPE bal_t_logh.

    IF gv_log_handle IS NOT INITIAL.
      " CALL FUNCTION no acepta expresiones: usar variable
      INSERT gv_log_handle INTO TABLE lt_handles.

      CALL FUNCTION 'BAL_DB_SAVE'
        EXPORTING
          i_t_log_handle   = lt_handles
        EXCEPTIONS
          log_not_found    = 1
          save_not_allowed = 2
          numbering_error  = 3
          OTHERS           = 4.
    ENDIF.
    export_to_table( ).
  ENDMETHOD.

  METHOD get_log_entries.
    rt_entries = gt_log_entries.
  ENDMETHOD.

  METHOD display_log_alv.
    DATA: lo_alv TYPE REF TO cl_salv_table.

    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = lo_alv
          CHANGING  t_table      = gt_log_entries
        ).
        lo_alv->get_functions( )->set_all( abap_true ).
        lo_alv->get_columns( )->optimize( ).
        lo_alv->display( ).
      CATCH cx_salv_msg INTO DATA(lx_msg).
        MESSAGE lx_msg->get_text( ) TYPE 'E'.
    ENDTRY.
  ENDMETHOD.

  METHOD export_to_table.
    DATA: lt_entries    TYPE gtt_log_entries,
          lt_db_entries TYPE STANDARD TABLE OF zhr_cln_log,
          ls_db_entry   TYPE zhr_cln_log.

    IF it_entries IS SUPPLIED.
      lt_entries = it_entries.
    ELSE.
      lt_entries = gt_log_entries.
    ENDIF.

    IF lt_entries IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_entries INTO DATA(ls_entry).
      ls_db_entry = CORRESPONDING #( ls_entry ).
      ls_db_entry-mandt = sy-mandt.
      APPEND ls_db_entry TO lt_db_entries.
    ENDLOOP.

    INSERT zhr_cln_log FROM TABLE lt_db_entries ACCEPTING DUPLICATE KEYS.
  ENDMETHOD.

ENDCLASS.
