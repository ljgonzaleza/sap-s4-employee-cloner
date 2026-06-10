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

CLASS zcl_hr_cln_exporter DEFINITION CREATE PUBLIC.

  PUBLIC SECTION.

    " Tipos
    TYPES:
      BEGIN OF gty_export_data,
        pernr   TYPE pernr_d,
        infty   TYPE infty,
        seqnr   TYPE seqnr,
        begda   TYPE begda,
        endda   TYPE endda,
        data    TYPE string,  " JSON/XML con datos del registro
      END OF gty_export_data,
      gtt_export_data TYPE STANDARD TABLE OF gty_export_data.

    " Constructor
    METHODS constructor
      IMPORTING
        io_logger TYPE REF TO zcl_hr_cln_logger OPTIONAL.

    " Exportar resultados a archivo
    METHODS export_to_file
      IMPORTING
        it_results   TYPE zcl_hr_cln_orchestrator=>gtt_results
        iv_format    TYPE char4 DEFAULT 'XLSX'
        iv_path      TYPE localfile OPTIONAL
        iv_split     TYPE abap_bool DEFAULT abap_false
      EXPORTING
        ev_file_path TYPE string.

    " Exportar datos de infotipo
    METHODS export_infotype_data
      IMPORTING
        iv_pernr TYPE pernr_d
        iv_infty TYPE infty
        it_data  TYPE STANDARD TABLE.

    " Generar archivo Excel
    METHODS generate_excel
      IMPORTING
        it_data      TYPE gtt_export_data
        iv_filename  TYPE string
      EXPORTING
        ev_filepath  TYPE string.

    " Generar archivo CSV
    METHODS generate_csv
      IMPORTING
        it_data      TYPE gtt_export_data
        iv_filename  TYPE string
      EXPORTING
        ev_filepath  TYPE string.

    " Descargar archivo a PC local
    CLASS-METHODS download_to_pc
      IMPORTING
        iv_filename TYPE string
        iv_data     TYPE xstring
      EXPORTING
        ev_path     TYPE string.

  PROTECTED SECTION.

    DATA: go_logger TYPE REF TO zcl_hr_cln_logger.

    " Convertir datos a formato JSON
    METHODS convert_to_json
      IMPORTING
        is_data        TYPE any
      RETURNING
        VALUE(rv_json) TYPE string.

    " Crear estructura para Excel
    METHODS create_excel_structure
      IMPORTING
        it_data           TYPE gtt_export_data
      RETURNING
        VALUE(rt_sheets)  TYPE STANDARD TABLE OF string.

    " Obtener path por defecto
    METHODS get_default_path
      RETURNING
        VALUE(rv_path) TYPE string.

  PRIVATE SECTION.

    CONSTANTS:
      gc_format_xlsx TYPE char4 VALUE 'XLSX',
      gc_format_csv  TYPE char4 VALUE 'CSV'.

ENDCLASS.

CLASS zcl_hr_cln_exporter IMPLEMENTATION.

*--------------------------------------------------------------------*
* Constructor
*--------------------------------------------------------------------*
  METHOD constructor.
    go_logger = io_logger.
  ENDMETHOD.

*--------------------------------------------------------------------*
* Exportar resultados a archivo
*--------------------------------------------------------------------*
  METHOD export_to_file.

    DATA: lt_export_data TYPE gtt_export_data,
          lv_filename    TYPE string.

    " Preparar datos para exportación
    LOOP AT it_results INTO DATA(ls_result).

      APPEND VALUE #(
        pernr = ls_result-pernr_src
        infty = '0000'
        data  = |Origen: { ls_result-pernr_src }, Destino: { ls_result-pernr_tgt }|
      ) TO lt_export_data.

    ENDLOOP.

    " Determinar nombre de archivo
    IF iv_split = abap_true.
      " Un archivo por empleado
      LOOP AT it_results INTO ls_result.
        lv_filename = |CLONE_{ ls_result-pernr_src }_{ sy-datum }.{ iv_format }|.

        CASE iv_format.
          WHEN gc_format_xlsx.
            generate_excel(
              EXPORTING
                it_data     = lt_export_data
                iv_filename = lv_filename
              IMPORTING
                ev_filepath = ev_file_path
            ).

          WHEN gc_format_csv.
            generate_csv(
              EXPORTING
                it_data     = lt_export_data
                iv_filename = lv_filename
              IMPORTING
                ev_filepath = ev_file_path
            ).

          WHEN OTHERS.
            IF go_logger IS BOUND.
              go_logger->log_warning(
                iv_msg = |Formato { iv_format } no soportado|
              ).
            ENDIF.
        ENDCASE.

      ENDLOOP.

    ELSE.
      " Archivo único
      lv_filename = |CLONE_EXPORT_{ sy-datum }_{ sy-uzeit }.{ iv_format }|.

      CASE iv_format.
        WHEN gc_format_xlsx.
          generate_excel(
            EXPORTING
              it_data     = lt_export_data
              iv_filename = lv_filename
            IMPORTING
              ev_filepath = ev_file_path
          ).

        WHEN gc_format_csv.
          generate_csv(
            EXPORTING
              it_data     = lt_export_data
              iv_filename = lv_filename
            IMPORTING
              ev_filepath = ev_file_path
          ).

        WHEN OTHERS.
          IF go_logger IS BOUND.
            go_logger->log_warning(
              iv_msg = |Formato { iv_format } no soportado|
            ).
          ENDIF.
      ENDCASE.

    ENDIF.

    " Loguear resultado
    IF ev_file_path IS NOT INITIAL AND go_logger IS BOUND.
      go_logger->log_success(
        iv_msg = |Archivo exportado: { ev_file_path }|
      ).
    ENDIF.

  ENDMETHOD.

*--------------------------------------------------------------------*
* Exportar datos de infotipo
*--------------------------------------------------------------------*
  METHOD export_infotype_data.

    DATA: lt_export TYPE gtt_export_data,
          lr_data   TYPE REF TO data.

    FIELD-SYMBOLS: <fs_data> TYPE STANDARD TABLE.

    " Convertir datos a estructura genérica
    LOOP AT it_data ASSIGNING FIELD-SYMBOL(<fs_row>).

      APPEND VALUE #(
        pernr = iv_pernr
        infty = iv_infty
        data  = convert_to_json( <fs_row> )
      ) TO lt_export.

    ENDLOOP.

  ENDMETHOD.

*--------------------------------------------------------------------*
* Generar archivo Excel
*--------------------------------------------------------------------*
  METHOD generate_excel.

    DATA: lv_fullpath TYPE string,
          lv_path     TYPE string.

    " Obtener path por defecto si no se especifica
    lv_path = get_default_path( ).

    lv_fullpath = |{ lv_path }{ iv_filename }|.

    " Crear archivo Excel usando CL_XLSX_DOCUMENT
    " (Implementación simplificada - en producción usar API completa)

    DATA: lo_xlsx TYPE REF TO cl_xlsx_document,
          lo_sheet TYPE REF TO cl_xlsx_sheet,
          lv_xstring TYPE xstring.

    TRY.
        " Crear documento
        lo_xlsx = cl_xlsx_document=>create_document( ).

        " Obtener hoja activa
        lo_sheet = lo_xlsx->get_active_sheet( ).

        " Agregar datos
        lo_sheet->set_cell_value(
          iv_row    = 1
          iv_column = 1
          iv_value  = 'PERNR'
        ).

        lo_sheet->set_cell_value(
          iv_row    = 1
          iv_column = 2
          iv_value  = 'INFTY'
        ).

        lo_sheet->set_cell_value(
          iv_row    = 1
          iv_column = 3
          iv_value  = 'DATA'
        ).

        " Agregar filas de datos
        LOOP AT it_data INTO DATA(ls_row).
          DATA(lv_row) = sy-tabix + 1.

          lo_sheet->set_cell_value(
            iv_row    = lv_row
            iv_column = 1
            iv_value  = ls_row-pernr
          ).

          lo_sheet->set_cell_value(
            iv_row    = lv_row
            iv_column = 2
            iv_value  = ls_row-infty
          ).

          lo_sheet->set_cell_value(
            iv_row    = lv_row
            iv_column = 3
            iv_value  = ls_row-data
          ).

        ENDLOOP.

        " Guardar a xstring
        lv_xstring = lo_xlsx->save( ).

        " Descargar a PC
        download_to_pc(
          EXPORTING
            iv_filename = iv_filename
            iv_data       = lv_xstring
          IMPORTING
            ev_path       = ev_filepath
        ).

      CATCH cx_xlsx_error INTO DATA(lx_xlsx).
        IF go_logger IS BOUND.
          go_logger->log_error(
            iv_msg = |Error generando Excel: { lx_xlsx->get_text( ) }|
          ).
        ENDIF.
    ENDTRY.

  ENDMETHOD.

*--------------------------------------------------------------------*
* Generar archivo CSV
*--------------------------------------------------------------------*
  METHOD generate_csv.

    DATA: lt_csv      TYPE STANDARD TABLE OF string,
          lv_csv_line TYPE string,
          lv_xstring  TYPE xstring,
          lv_fullpath TYPE string.

    " Cabecera
    lv_csv_line = 'PERNR;INFTY;SEQNR;BEGDA;ENDDA;DATA'.
    APPEND lv_csv_line TO lt_csv.

    " Datos
    LOOP AT it_data INTO DATA(ls_row).
      lv_csv_line = |{ ls_row-pernr };{ ls_row-infty };{ ls_row-seqnr };{ ls_row-begda };{ ls_row-endda };{ ls_row-data }|.
      APPEND lv_csv_line TO lt_csv.
    ENDLOOP.

    " Convertir a xstring
    lv_xstring = cl_abap_codepage=>convert_to(
      source = concat_lines_of( table = lt_csv sep = cl_abap_char_utilities=>cr_lf )
      codepage = 'UTF-8'
    ).

    " Descargar
    download_to_pc(
      EXPORTING
        iv_filename = iv_filename
        iv_data       = lv_xstring
      IMPORTING
        ev_path       = ev_filepath
    ).

  ENDMETHOD.

*--------------------------------------------------------------------*
* Descargar archivo a PC local
*--------------------------------------------------------------------*
  CLASS-METHOD download_to_pc.

    DATA: lv_filename   TYPE string,
          lv_path       TYPE string,
          lv_fullpath   TYPE string.

    lv_filename = iv_filename.

    " Usar GUI_DOWNLOAD para descargar a PC
    cl_gui_frontend_services=>gui_download(
      EXPORTING
        bin_filesize              = xstrlen( iv_data )
        filename                  = lv_filename
        filetype                  = 'BIN'
      IMPORTING
        filelength                = DATA(lv_filelength)
      CHANGING
        data_tab                  = VALUE STANDARD TABLE OF x255( ( CONV x255( iv_data ) ) )
      EXCEPTIONS
        file_write_error          = 1
        no_batch                  = 2
        gui_refuse_filetransfer   = 3
        invalid_type              = 4
        no_authority              = 5
        unknown_error             = 6
        header_not_allowed        = 7
        separator_not_allowed     = 8
        filesize_not_allowed      = 9
        header_too_long           = 10
        dp_error_create           = 11
        dp_error_send             = 12
        no_writelength            = 13
        gui_invalid_fileformat    = 14
        unknown_dp_error          = 15
        access_denied             = 16
        OTHERS                    = 17
    ).

    IF sy-subrc = 0.
      ev_path = lv_filename.
    ENDIF.

  ENDMETHOD.

*--------------------------------------------------------------------*
* Convertir datos a JSON
*--------------------------------------------------------------------*
  METHOD convert_to_json.

    DATA: lr_data     TYPE REF TO data,
          lo_writer   TYPE REF TO cl_sxml_string_writer,
          lv_xstring  TYPE xstring.

    GET REFERENCE OF is_data INTO lr_data.

    " Usar CALL TRANSFORMATION para convertir a JSON
    lo_writer = cl_sxml_string_writer=>create( type = if_sxml=>co_xt_json ).

    CALL TRANSFORMATION id
      SOURCE data = lr_data->*
      RESULT XML lo_writer.

    lv_xstring = lo_writer->get_output( ).

    rv_json = cl_abap_codepage=>convert_from( lv_xstring ).

  ENDMETHOD.

*--------------------------------------------------------------------*
* Crear estructura para Excel
*--------------------------------------------------------------------*
  METHOD create_excel_structure.

    DATA: lt_sheets TYPE STANDARD TABLE OF string.

    " Crear hojas según categoría
    APPEND 'PA_Core' TO lt_sheets.
    APPEND 'PA_Adic' TO lt_sheets.
    APPEND 'Time_Mgmt' TO lt_sheets.
    APPEND 'Time_Tablas' TO lt_sheets.
    APPEND 'Localizacion' TO lt_sheets.
    APPEND 'Infotipos_Z' TO lt_sheets.
    APPEND 'Log' TO lt_sheets.

    rt_sheets = lt_sheets.

  ENDMETHOD.

*--------------------------------------------------------------------*
* Obtener path por defecto
*--------------------------------------------------------------------*
  METHOD get_default_path.

    DATA: lv_path TYPE string.

    " Obtener directorio por defecto
    cl_gui_frontend_services=>get_temp_dir(
      CHANGING
        temp_dir             = lv_path
      EXCEPTIONS
        cntl_error           = 1
        error_no_gui         = 2
        wrong_parameter      = 3
        not_supported_by_gui = 4
        OTHERS               = 5
    ).

    IF sy-subrc = 0.
      rv_path = lv_path.
    ELSE.
      rv_path = 'C:\\TEMP\\'.
    ENDIF.

  ENDMETHOD.

ENDCLASS.