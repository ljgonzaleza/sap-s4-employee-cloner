*&============================================================*
*& Interface ZIF_HR_CLN_BADI                                  *
*&============================================================*
*& Descripción: BAdI para extensibilidad del clonador de       *
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

INTERFACE zif_hr_cln_badi
  PUBLIC.

  CONSTANTS:
    gc_skip_no     TYPE char1 VALUE ' ',
    gc_skip_yes    TYPE char1 VALUE 'X',
    gc_skip_modify TYPE char1 VALUE 'M'.

  TYPES:
    BEGIN OF gty_context,
      pernr_src TYPE pernr_d,
      pernr_tgt TYPE pernr_d,
      infty     TYPE infty,
      subty     TYPE subty,
      seqnr     TYPE seqnr,
    END OF gty_context.

  " RETURNING no se puede combinar con CHANGING: se usa EXPORTING
  METHODS adjust_source_before_copy
    IMPORTING
      is_context TYPE gty_context
    EXPORTING
      ev_subrc   TYPE sysubrc
    CHANGING
      cs_data    TYPE any.

  METHODS adjust_target_before_save
    IMPORTING
      is_context TYPE gty_context
      is_source  TYPE any
    EXPORTING
      ev_subrc   TYPE sysubrc
    CHANGING
      cs_target  TYPE any.

  METHODS skip_infotype
    IMPORTING
      is_context     TYPE gty_context
    RETURNING
      VALUE(rv_skip) TYPE char1.

  METHODS after_infotype_copy
    IMPORTING
      is_context      TYPE gty_context
      iv_seqnr_tgt    TYPE seqnr
      iv_success      TYPE abap_bool
    RETURNING
      VALUE(rv_subrc) TYPE sysubrc.

  METHODS after_clone_complete
    IMPORTING
      it_results      TYPE STANDARD TABLE
    RETURNING
      VALUE(rv_subrc) TYPE sysubrc.

ENDINTERFACE.
