*&============================================================*
*& Class ZCL_HR_CLN_EXPORTER
*&============================================================*
*& Descripción: Exportador de datos clonados a archivo local   *
*& (Excel/CSV) para análisis offline o carga en otro ambiente  *
*& Fecha Creación = 10.06.2026                              *
*& Creador      = LATAM Development Team                    *
*& Empresa      = LATAM                                     *
*&============================================================*
*& Histórico de modificaciones                              *
*&============================================================*
*& Marca  Fecha       Autor  Descripción                      *
*& @001   2026.06.10  —     Versión inicial                  *
*&============================================================*

CLASS zcl_hr_cln_exporter DEFINITION PUBLIC CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF gty_export_data,
        pernr TYPE pernr_d,
        infty TYPE infty,
        seqnr TYPE seqnr,
        begda TYPE begda,
        endda TYPE endda,
        data  TYPE string,
      END OF gty_export_data,
      gtt_export_data TYPE STANDARD TABLE OF gty_export_data WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING
        io_logger TYPE REF TO zcl_hr_cln_logger OPTIONAL.

    METHODS export_to_file
      IMPORTING
        it_results   TYPE zcl_hr_cln_orchestrator=>gtt_results
        iv_format    TYPE char4 DEFAULT 'XLSX'
        iv_path      TYPE localfile OPTIONAL
        iv_split     TYPE abap_bool DEFAULT abap_false
      EXPORTING
        ev_file_path TYPE string.

    METHODS export_infotype_data
      IMPORTING
        iv_pernr TYPE pernr_d
        iv_infty TYPE infty
        it_data  TYPE STANDARD TABLE.

    METHODS generate_excel
      IMPORTING
        it_data     TYPE gtt_export_data
        iv_filename TYPE string
      EXPORTING
        ev_filepath TYPE string.

    METHODS generate_csv
      IMPORTING
        it_data     TYPE gtt_export_data
        iv_filename TYPE string
      EXPORTING
        ev_filepath TYPE string.

    CLASS-METHODS download_to_pc
      IMPORTING
        iv_filename TYPE string
        iv_data     TYPE xstring
      EXPORTING
        ev_path     TYPE string.

  PROTECTED SECTION.

    DATA: go_logger TYPE REF TO zcl_hr_cln_logger.

    METHODS convert_to_json
      IMPORTING
        is_data        TYPE any
      RETURNING
        VALUE(rv_json) TYPE string.

    METHODS get_default_path
      RETURNING
        VALUE(rv_path) TYPE string.

  PRIVATE SECTION.

    CONSTANTS:
      gc_format_xlsx TYPE char4 VALUE 'XLSX',
      gc_format_csv  TYPE char4 VALUE 'CSV'.

ENDCLASS.

CLASS zcl_hr_cln_exporter IMPLEMENTATION.

  METHOD constructor.
    go_logger = io_logger.
  ENDMETHOD.

  METHOD export_to_file.
    DATA: lt_export_data TYPE gtt_export_data,
          lv_filename    TYPE string,
          lv_dir         TYPE string.

    LOOP AT it_results INTO DATA(ls_result).
      APPEND VALUE #(
        pernr = ls_result-pernr_src
        infty = '0000'
        data  = |Origen: { ls_result-pernr_src }, Destino: { ls_result-pernr_tgt }|
      ) TO lt_export_data.
    ENDLOOP.

    " Obtener y normalizar directorio base
    IF iv_path IS NOT INITIAL.
      lv_dir = iv_path.
    ELSE.
      lv_dir = get_default_path( ).
    ENDIF.

    DATA(lv_len) = strlen( lv_dir ).
    IF lv_len > 0.
      DATA(lv_last) = lv_dir+lv_len-1(1).
      IF lv_last <> '\' AND lv_last <> '/'.
        lv_dir = lv_dir && `\`.
      ENDIF.
    ENDIF.

    IF iv_split = abap_true.
      LOOP AT it_results INTO ls_result.
        lv_filename = |{ lv_dir }CLONE_{ ls_result-pernr_src }_{ sy-datum }.{ iv_format }|.
        CASE iv_format.
          WHEN gc_format_xlsx.
            generate_excel( EXPORTING it_data = lt_export_data iv_filename = lv_filename IMPORTING ev_filepath = ev_file_path ).
          WHEN gc_format_csv.
            generate_csv( EXPORTING it_data = lt_export_data iv_filename = lv_filename IMPORTING ev_filepath = ev_file_path ).
          WHEN OTHERS.
            IF go_logger IS BOUND.
              go_logger->log_warning( iv_msg = |Formato { iv_format } no soportado| ).
            ENDIF.
        ENDCASE.
      ENDLOOP.
    ELSE.
      lv_filename = |{ lv_dir }CLONE_EXPORT_{ sy-datum }_{ sy-uzeit }.{ iv_format }|.
      CASE iv_format.
        WHEN gc_format_xlsx.
          generate_excel( EXPORTING it_data = lt_export_data iv_filename = lv_filename IMPORTING ev_filepath = ev_file_path ).
        WHEN gc_format_csv.
          generate_csv( EXPORTING it_data = lt_export_data iv_filename = lv_filename IMPORTING ev_filepath = ev_file_path ).
        WHEN OTHERS.
          IF go_logger IS BOUND.
            go_logger->log_warning( iv_msg = |Formato { iv_format } no soportado| ).
          ENDIF.
      ENDCASE.
    ENDIF.

    IF ev_file_path IS NOT INITIAL AND go_logger IS BOUND.
      go_logger->log_success( iv_msg = |Archivo exportado: { ev_file_path }| ).
    ENDIF.
  ENDMETHOD.

  METHOD export_infotype_data.
    DATA: lt_export TYPE gtt_export_data.

    LOOP AT it_data ASSIGNING FIELD-SYMBOL(<fs_row>).
      APPEND VALUE #( pernr = iv_pernr infty = iv_infty data = convert_to_json( <fs_row> ) ) TO lt_export.
    ENDLOOP.
  ENDMETHOD.

  METHOD generate_excel.
    " Generación XLSX nativa pendiente (requiere ABAP2XLSX o
    " transformación OpenXML). Se entrega CSV compatible con Excel.
    DATA(lv_filename) = iv_filename.
    REPLACE FIRST OCCURRENCE OF '.XLSX' IN lv_filename WITH '.csv'.
    REPLACE FIRST OCCURRENCE OF '.xlsx' IN lv_filename WITH '.csv'.

    generate_csv(
      EXPORTING it_data = it_data iv_filename = lv_filename
      IMPORTING ev_filepath = ev_filepath
    ).

    IF go_logger IS BOUND.
      go_logger->log_warning(
        iv_msg = |XLSX pendiente: se generó CSV { ev_filepath }|
      ).
    ENDIF.
  ENDMETHOD.

  METHOD generate_csv.
    DATA: lt_csv      TYPE STANDARD TABLE OF string,
          lv_csv_line TYPE string.

    lv_csv_line = 'PERNR;INFTY;SEQNR;BEGDA;ENDDA;DATA'.
    APPEND lv_csv_line TO lt_csv.

    LOOP AT it_data INTO DATA(ls_row).
      lv_csv_line = |{ ls_row-pernr };{ ls_row-infty };{ ls_row-seqnr };{ ls_row-begda };{ ls_row-endda };{ ls_row-data }|.
      APPEND lv_csv_line TO lt_csv.
    ENDLOOP.

    DATA(lv_xstring) = cl_abap_codepage=>convert_to(
      source   = concat_lines_of( table = lt_csv sep = cl_abap_char_utilities=>cr_lf )
      codepage = 'UTF-8'
    ).

    download_to_pc( EXPORTING iv_filename = iv_filename iv_data = lv_xstring IMPORTING ev_path = ev_filepath ).
  ENDMETHOD.

  METHOD download_to_pc.
    DATA: lt_data   TYPE STANDARD TABLE OF x255,
          lv_length TYPE i,
          lv_path   TYPE string.

    " Convertir xstring a tabla binaria
    CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
      EXPORTING
        buffer        = iv_data
      IMPORTING
        output_length = lv_length
      TABLES
        binary_tab    = lt_data.

    lv_path = iv_filename.

    cl_gui_frontend_services=>gui_download(
      EXPORTING
        bin_filesize            = lv_length
        filename                = lv_path
        filetype                = 'BIN'
      CHANGING
        data_tab                = lt_data
      EXCEPTIONS
        file_write_error        = 1
        no_batch                = 2
        gui_refuse_filetransfer = 3
        OTHERS                  = 17
    ).

    IF sy-subrc <> 0.
      " Si falla (ej: la ruta C:\temp\ no existe), descargar en el directorio temporal del GUI
      DATA: lv_temp_dir TYPE string,
            lv_name     TYPE string.

      cl_gui_frontend_services=>get_temp_directory(
        CHANGING
          temp_dir             = lv_temp_dir
        EXCEPTIONS
          OTHERS               = 5
      ).

      IF sy-subrc = 0 AND lv_temp_dir IS NOT INITIAL.
        CALL FUNCTION 'SO_SPLIT_FILE_AND_PATH'
          EXPORTING
            full_name     = lv_path
          IMPORTING
            stripped_name = lv_name.

        DATA(lv_len_temp) = strlen( lv_temp_dir ).
        IF lv_len_temp > 0.
          DATA(lv_last_temp) = lv_temp_dir+lv_len_temp-1(1).
          IF lv_last_temp <> '\' AND lv_last_temp <> '/'.
            lv_temp_dir = lv_temp_dir && `\`.
          ENDIF.
        ENDIF.

        lv_path = lv_temp_dir && lv_name.

        cl_gui_frontend_services=>gui_download(
          EXPORTING
            bin_filesize            = lv_length
            filename                = lv_path
            filetype                = 'BIN'
          CHANGING
            data_tab                = lt_data
          EXCEPTIONS
            OTHERS                  = 17
        ).
      ENDIF.
    ENDIF.

    IF sy-subrc = 0.
      ev_path = lv_path.
    ENDIF.
  ENDMETHOD.

  METHOD convert_to_json.
    DATA: lo_writer  TYPE REF TO cl_sxml_string_writer,
          lv_xstring TYPE xstring.

    TRY.
        lo_writer = cl_sxml_string_writer=>create( type = if_sxml=>co_xt_json ).

        CALL TRANSFORMATION id
          SOURCE data = is_data
          RESULT XML lo_writer.

        lv_xstring = lo_writer->get_output( ).
        rv_json = cl_abap_codepage=>convert_from( lv_xstring ).
      CATCH cx_root.
        rv_json = |\{"error": "Error de serialización JSON"\}|.
    ENDTRY.
  ENDMETHOD.

  METHOD get_default_path.
    cl_gui_frontend_services=>get_temp_directory(
      CHANGING
        temp_dir             = rv_path
      EXCEPTIONS
        cntl_error           = 1
        error_no_gui         = 2
        wrong_parameter      = 3
        not_supported_by_gui = 4
        OTHERS               = 5
    ).

    IF sy-subrc <> 0.
      rv_path = 'C:\\TEMP\\'.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
