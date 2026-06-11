*&============================================================*
*& Class ZCL_HR_UPL_VALIDATOR
*&============================================================*
*& Descripción: Validador de estructura de archivos de carga   *
*& para el programa de upload                                  *
*& Fecha Creación = 10.06.2026                              *
*& Creador      = LATAM Development Team                    *
*& Empresa      = LATAM                                     *
*&============================================================*
*& Histórico de modificaciones                              *
*&============================================================*
*& Marca  Fecha       Autor  Descripción                      *
*& @001   2026.06.10  —     Versión inicial                  *
*&============================================================*

CLASS zcl_hr_upl_validator DEFINITION PUBLIC CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS validate_structure
      IMPORTING
        it_employees    TYPE zcl_hr_upl_parser=>gtt_employees
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

ENDCLASS.

CLASS zcl_hr_upl_validator IMPLEMENTATION.

  METHOD validate_structure.
    rv_valid = abap_true.

    IF it_employees IS INITIAL.
      rv_valid = abap_false.
      RETURN.
    ENDIF.

    LOOP AT it_employees INTO DATA(ls_employee).
      IF ls_employee-pernr IS INITIAL.
        rv_valid = abap_false.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
