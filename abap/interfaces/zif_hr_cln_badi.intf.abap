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

*--------------------------------------------------------------------*
* Constantes
*--------------------------------------------------------------------*
  CONSTANTS:
    gc_skip_no     TYPE char1 VALUE ' ',
    gc_skip_yes    TYPE char1 VALUE 'X',
    gc_skip_modify TYPE char1 VALUE 'M'.

*--------------------------------------------------------------------*
* Tipos
*--------------------------------------------------------------------*
  TYPES:
    BEGIN OF gty_context,
      pernr_src TYPE pernr_d,
      pernr_tgt TYPE pernr_d,
      infty     TYPE infty,
      subty     TYPE subty,
      seqnr     TYPE seqnr,
    END OF gty_context.

*--------------------------------------------------------------------*
* Métodos
*--------------------------------------------------------------------*

  " Modificar registro origen antes de copiar
  METHODS adjust_source_before_copy
    IMPORTING
      is_context    TYPE gty_context
    CHANGING
      cs_data       TYPE any
    RETURNING
      VALUE(rv_subrc) TYPE sysubrc.

  " Modificar registro destino antes de grabar
  METHODS adjust_target_before_save
    IMPORTING
      is_context    TYPE gty_context
      is_source     TYPE any
    CHANGING
      cs_target     TYPE any
    RETURNING
      VALUE(rv_subrc) TYPE sysubrc.

  " Lógica custom para omitir infotipo
  METHODS skip_infotype
    IMPORTING
      is_context     TYPE gty_context
    RETURNING
      VALUE(rv_skip) TYPE char1.

  " Post-proceso por infotipo
  METHODS after_infotype_copy
    IMPORTING
      is_context    TYPE gty_context
      iv_seqnr_tgt  TYPE seqnr
      iv_success    TYPE abap_bool
    RETURNING
      VALUE(rv_subrc) TYPE sysubrc.

  " Notificaciones, workflow, etc. después de clonación completa
  METHODS after_clone_complete
    IMPORTING
      it_results    TYPE STANDARD TABLE
    RETURNING
      VALUE(rv_subrc) TYPE sysubrc.

ENDINTERFACE.