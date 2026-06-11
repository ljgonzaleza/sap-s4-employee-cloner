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

CLASS zcl_hr_upl_file_reader DEFINITION CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS constructor.

    METHODS read_file
      IMPORTING
        iv_path        TYPE localfile
        iv_format      TYPE char4 DEFAULT 'XLSX'
      EXPORTING
        et_data        TYPE STANDARD TABLE
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    METHODS read_excel
      IMPORTING
        iv_path        TYPE localfile
      EXPORTING
        et_sheets      TYPE STANDARD TABLE
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    METHODS read_csv
      IMPORTING
        iv_path        TYPE localfile
      EXPORTING
        et_lines       TYPE STANDARD TABLE OF string
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    METHODS validate_file_exists
      IMPORTING
        iv_path         TYPE localfile
      RETURNING
        VALUE(rv_exists) TYPE abap_bool.

    METHODS get_file_size
      IMPORTING
        iv_path        TYPE localfile
      RETURNING
        VALUE(rv_size) TYPE i.

  PROTECTED SECTION.

    DATA: mv_max_size TYPE i VALUE 52428800.

    METHODS check_file_size
      IMPORTING
        iv_path         TYPE localfile
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

ENDCLASS.

CLASS zcl_hr_upl_file_reader IMPLEMENTATION.

  METHOD constructor.
  ENDMETHOD.

  METHOD read_file.
    IF validate_file_exists( iv_path ) = abap_false.
      rv_valid = abap_false.
      RETURN.
    ENDIF.

    IF check_file_size( iv_path ) = abap_false.
      rv_valid = abap_false.
      RETURN.
    ENDIF.

    CASE iv_format.
      WHEN 'XLSX'.
        rv_valid = read_excel( EXPORTING iv_path = iv_path IMPORTING et_sheets = et_data ).
      WHEN 'CSV'.
        rv_valid = read_csv( EXPORTING iv_path = iv_path IMPORTING et_lines = et_data ).
      WHEN OTHERS.
        rv_valid = abap_false.
    ENDCASE.
  ENDMETHOD.

  METHOD read_excel.
    DATA: lt_data   TYPE STANDARD TABLE OF x255,
          lv_length TYPE i.

    cl_gui_frontend_services=>gui_upload(
      EXPORTING
        filename                = iv_path
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
      rv_valid = abap_false.
      RETURN.
    ENDIF.

    DATA(lv_xstring) = cl_bcs_convert=>xtab_to_xstring( it_xtab = lt_data iv_size = lv_length ).

    TRY.
        DATA(lo_xlsx) = cl_xlsx_document=>load_document( lv_xstring ).
        DATA(lt_sheets) = lo_xlsx->get_sheets( ).

        LOOP AT lt_sheets INTO DATA(lo_sheet).
          APPEND lo_sheet->get_name( ) TO et_sheets.
        ENDLOOP.

        rv_valid = abap_true.

      CATCH cx_xlsx_error.
        rv_valid = abap_false.
    ENDTRY.
  ENDMETHOD.

  METHOD read_csv.
    DATA: lt_data TYPE STANDARD TABLE OF x255.

    cl_gui_frontend_services=>gui_upload(
      EXPORTING
        filename                = iv_path
        filetype                = 'ASC'
        codepage                = '4110'
      CHANGING
        data_tab                = lt_data
      EXCEPTIONS
        file_open_error         = 1
        file_read_error         = 2
        OTHERS                  = 14
    ).

    IF sy-subrc <> 0.
      rv_valid = abap_false.
      RETURN.
    ENDIF.

    LOOP AT lt_data INTO DATA(ls_xline).
      APPEND cl_abap_codepage=>convert_from( source = ls_xline codepage = 'UTF-8' ) TO et_lines.
    ENDLOOP.

    rv_valid = abap_true.
  ENDMETHOD.

  METHOD validate_file_exists.
    cl_gui_frontend_services=>file_exist(
      EXPORTING
        file                 = iv_path
      RECEIVING
        result               = rv_exists
      EXCEPTIONS
        cntl_error           = 1
        error_no_gui         = 2
        wrong_parameter      = 3
        not_supported_by_gui = 4
        OTHERS               = 5
    ).
  ENDMETHOD.

  METHOD get_file_size.
    DATA: lv_size TYPE i.

    cl_gui_frontend_services=>file_get_size(
      EXPORTING
        filename             = iv_path
      CHANGING
        filesize             = lv_size
      EXCEPTIONS
        cntl_error           = 1
        error_no_gui         = 2
        wrong_parameter      = 3
        not_supported_by_gui = 4
        OTHERS               = 5
    ).

    rv_size = COND #( WHEN sy-subrc = 0 THEN lv_size ELSE 0 ).
  ENDMETHOD.

  METHOD check_file_size.
    DATA(lv_size) = get_file_size( iv_path ).
    rv_valid = xsdbool( lv_size > 0 AND lv_size <= mv_max_size ).
  ENDMETHOD.

ENDCLASS.
