*&============================================================*
*& Class ZCL_HR_UPL_FILE_READER
*&============================================================*
*& Descripción: Lector de archivos Excel/CSV desde PC local   *
*& para programa de upload                                     *
*& Fecha Creación = 10.06.2026                              *
*& Creador      = LATAM Development Team                    *
*& Empresa      = LATAM                                     *
*&============================================================*
*& Histórico de modificaciones                              *
*&============================================================*
*& Marca  Fecha       Autor  Descripción                      *
*& @001   2026.06.10  —     Versión inicial                  *
*&============================================================*

CLASS zcl_hr_upl_file_reader DEFINITION PUBLIC CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS constructor.

    " RETURNING no se combina con EXPORTING: todo por EXPORTING
    METHODS read_csv
      IMPORTING
        iv_path  TYPE localfile
      EXPORTING
        et_lines TYPE string_table
        ev_valid TYPE abap_bool.

    METHODS read_binary
      IMPORTING
        iv_path    TYPE localfile
      EXPORTING
        ev_xstring TYPE xstring
        ev_valid   TYPE abap_bool.

    METHODS validate_file_exists
      IMPORTING
        iv_path          TYPE localfile
      RETURNING
        VALUE(rv_exists) TYPE abap_bool.

    METHODS get_file_size
      IMPORTING
        iv_path        TYPE localfile
      RETURNING
        VALUE(rv_size) TYPE i.

  PROTECTED SECTION.

    DATA: gv_max_size TYPE i VALUE 52428800.  " 50MB

    METHODS check_file_size
      IMPORTING
        iv_path         TYPE localfile
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

ENDCLASS.

CLASS zcl_hr_upl_file_reader IMPLEMENTATION.

  METHOD constructor.
  ENDMETHOD.

  METHOD read_csv.
    DATA: lv_xstring TYPE xstring,
          lv_string  TYPE string.

    CLEAR: et_lines, ev_valid.

    " Leer el archivo en binario de forma 100% segura usando x255
    read_binary(
      EXPORTING iv_path    = iv_path
      IMPORTING ev_xstring = lv_xstring
                ev_valid   = ev_valid
    ).

    IF ev_valid = abap_false.
      RETURN.
    ENDIF.

    " Convertir binario a string de forma dump-proof
    TRY.
        lv_string = cl_abap_codepage=>convert_from(
          source   = lv_xstring
          codepage = 'UTF-8'
        ).
      CATCH cx_root.
        TRY.
            cl_abap_conv_in_class=>create( )->convert(
              EXPORTING input = lv_xstring
              IMPORTING data  = lv_string
            ).
          CATCH cx_root.
            ev_valid = abap_false.
            RETURN.
        ENDTRY.
    ENDTRY.

    " Dividir el string por CR/LF o LF
    SPLIT lv_string AT cl_abap_char_utilities=>cr_lf INTO TABLE et_lines.
    IF et_lines IS INITIAL.
      SPLIT lv_string AT cl_abap_char_utilities=>newline INTO TABLE et_lines.
    ENDIF.

    ev_valid = abap_true.
  ENDMETHOD.

  METHOD read_binary.
    DATA: lt_data     TYPE STANDARD TABLE OF x255,
          lv_length   TYPE i,
          lv_filename TYPE string.

    CLEAR: ev_xstring, ev_valid.

    IF validate_file_exists( iv_path ) = abap_false OR
       check_file_size( iv_path ) = abap_false.
      RETURN.
    ENDIF.

    lv_filename = iv_path.

    cl_gui_frontend_services=>gui_upload(
      EXPORTING
        filename                = lv_filename
        filetype                = 'BIN'
      IMPORTING
        filelength              = lv_length
      CHANGING
        data_tab                = lt_data
      EXCEPTIONS
        file_open_error         = 1
        file_read_error         = 2
        no_batch                = 3
        gui_refuse_filetransfer = 4
        OTHERS                  = 8
    ).

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    ev_xstring = cl_bcs_convert=>xtab_to_xstring(
      it_xtab = lt_data
      iv_size = lv_length
    ).

    ev_valid = abap_true.
  ENDMETHOD.

  METHOD validate_file_exists.
    DATA: lv_file TYPE string.

    lv_file = iv_path.

    cl_gui_frontend_services=>file_exist(
      EXPORTING
        file                 = lv_file
      RECEIVING
        result               = rv_exists
      EXCEPTIONS
        cntl_error           = 1
        error_no_gui         = 2
        wrong_parameter      = 3
        not_supported_by_gui = 4
        OTHERS               = 5
    ).

    IF sy-subrc <> 0.
      rv_exists = abap_false.
    ENDIF.
  ENDMETHOD.

  METHOD get_file_size.
    DATA: lv_size     TYPE i,
          lv_filename TYPE string.

    lv_filename = iv_path.

    cl_gui_frontend_services=>file_get_size(
      EXPORTING
        file_name            = lv_filename
      IMPORTING
        file_size            = lv_size
      EXCEPTIONS
        file_get_size_failed = 1
        cntl_error           = 2
        error_no_gui         = 3
        not_supported_by_gui = 4
        OTHERS               = 5
    ).

    rv_size = COND #( WHEN sy-subrc = 0 THEN lv_size ELSE 0 ).
  ENDMETHOD.

  METHOD check_file_size.
    DATA(lv_size) = get_file_size( iv_path ).
    rv_valid = xsdbool( lv_size > 0 AND lv_size <= gv_max_size ).
  ENDMETHOD.

ENDCLASS.
