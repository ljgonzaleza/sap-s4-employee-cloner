*&============================================================*
*& Class ZCL_HR_CLN_ITYPE_0002
*&============================================================*
*& Descripción: Handler para infotipo 0002 (Datos Personales)  *
*& del clonador de empleados SAP S/4HANA                       *
*& Fecha Creación = 10.06.2026                              *
*& Creador      = LATAM Development Team                    *
*& Empresa      = LATAM                                     *
*&============================================================*
*& Histórico de modificaciones                              *
*&============================================================*
*& Marca  Fecha       Autor  Descripción                      *
*& @001   2026.06.10  —     Versión inicial                  *
*&============================================================*

CLASS zcl_hr_cln_itype_0002 DEFINITION
  PUBLIC
  INHERITING FROM zcl_hr_cln_itype_base
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS: gc_infty TYPE infty VALUE '0002'.

    METHODS constructor
      IMPORTING
        io_logger TYPE REF TO zcl_hr_cln_logger OPTIONAL.

    METHODS clone REDEFINITION.
    METHODS supports_infty REDEFINITION.
    METHODS get_infty REDEFINITION.

  PROTECTED SECTION.

    TYPES:
      BEGIN OF gty_player,
        vorna TYPE string,
        nachn TYPE string,
      END OF gty_player,
      gtt_players TYPE STANDARD TABLE OF gty_player WITH DEFAULT KEY.

    METHODS clean_personal_ids
      IMPORTING
        is_params TYPE zhr_cln_params
      CHANGING
        cs_data   TYPE p0002.

    METHODS assign_fictitious_name
      IMPORTING
        iv_pernr TYPE pernr_d
      CHANGING
        cs_data  TYPE p0002.

    METHODS generate_dummy_id
      IMPORTING
        iv_prefix       TYPE string
        iv_original     TYPE string
      RETURNING
        VALUE(rv_dummy) TYPE string.

  PRIVATE SECTION.

    " Catálogo de futbolistas destacados de toda la historia (Masculino)
    CLASS-DATA: gt_players TYPE gtt_players.

    " Catálogo de mujeres famosas (Femenino)
    CLASS-DATA: gt_female_names TYPE gtt_players.

    CLASS-METHODS get_players
      RETURNING
        VALUE(rt_players) TYPE gtt_players.

    CLASS-METHODS get_female_names
      RETURNING
        VALUE(rt_female) TYPE gtt_players.

ENDCLASS.

CLASS zcl_hr_cln_itype_0002 IMPLEMENTATION.

  METHOD constructor.
    super->constructor( io_logger ).
  ENDMETHOD.

  METHOD supports_infty.
    rv_supported = xsdbool( iv_infty = gc_infty ).
  ENDMETHOD.

  METHOD get_infty.
    rv_infty = gc_infty.
  ENDMETHOD.

  METHOD clone.
    DATA: lt_source TYPE STANDARD TABLE OF p0002,
          ls_target TYPE p0002,
          ls_result TYPE gty_result,
          lv_seqnr  TYPE seqnr,
          lv_subrc  TYPE sysubrc.

    FIELD-SYMBOLS: <ls_source> TYPE p0002.

    CLEAR: et_results, et_seqnr_map.

    SELECT * FROM pa0002
     WHERE pernr = @iv_pernr_src
     ORDER BY begda
      INTO CORRESPONDING FIELDS OF TABLE @lt_source.

    IF sy-subrc <> 0.
      APPEND VALUE #(
        status  = gc_status_warning
        message = |No se encontraron registros IT 0002 para PERNR { iv_pernr_src }|
        pernr   = iv_pernr_tgt
        infty   = gc_infty
      ) TO et_results.
      RETURN.
    ENDIF.

    LOOP AT lt_source ASSIGNING <ls_source>.

      IF validate_record( is_data = <ls_source> is_params = is_params ) = abap_false.
        CONTINUE.
      ENDIF.

      CLEAR ls_result.
      ls_target = <ls_source>.

      transform_record(
        EXPORTING is_data = <ls_source> iv_pernr_tgt = iv_pernr_tgt is_params = is_params
        CHANGING  cs_data = ls_target
      ).

      clean_personal_ids( EXPORTING is_params = is_params CHANGING cs_data = ls_target ).

      " Anonimizar con nombres de futbolistas históricos
      IF is_params-anon_names = abap_true.
        assign_fictitious_name(
          EXPORTING iv_pernr = iv_pernr_tgt
          CHANGING  cs_data  = ls_target
        ).
      ENDIF.

      IF is_params-simulation = abap_false.

        write_target(
          EXPORTING
            iv_infty = gc_infty
            is_data  = ls_target
            iv_mode  = COND actio( WHEN is_params-overwrite = abap_true THEN 'MOD' ELSE 'INS' )
          IMPORTING
            ev_seqnr = lv_seqnr
            ev_subrc = lv_subrc
        ).

        ls_result-seqnr = lv_seqnr.

        IF lv_subrc = 0.
          ls_result-status  = gc_status_success.
          ls_result-message = |IT 0002 clonado exitosamente SEQNR { lv_seqnr }|.

          " Tabla hashed: usar INSERT, no APPEND
          INSERT VALUE #( infty     = gc_infty
                          seqnr_src = <ls_source>-seqnr
                          seqnr_tgt = lv_seqnr ) INTO TABLE et_seqnr_map.
        ELSE.
          ls_result-status  = gc_status_error.
          ls_result-message = |Error al clonar IT 0002 SEQNR { <ls_source>-seqnr }|.
        ENDIF.

      ELSE.
        ls_result-status  = gc_status_success.
        ls_result-message = |Simulación: IT 0002 listo para clonar SEQNR { <ls_source>-seqnr }|.
      ENDIF.

      ls_result-pernr = iv_pernr_tgt.
      ls_result-infty = gc_infty.
      APPEND ls_result TO et_results.

      IF go_logger IS BOUND.
        go_logger->log_success(
          iv_pernr_src = iv_pernr_src  iv_pernr_tgt = iv_pernr_tgt
          iv_infty     = gc_infty      iv_seqnr     = <ls_source>-seqnr
          iv_msg       = ls_result-message
        ).
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD clean_personal_ids.
    DATA: lv_mode TYPE char1.

    " Cliente implícito: no se filtra MANDT en Open SQL
    SELECT SINGLE uniq_cpf_mode
      FROM zhr_cln_config
      INTO @lv_mode.

    IF sy-subrc <> 0.
      lv_mode = 'L'.
    ENDIF.

    ASSIGN COMPONENT 'CPFNR' OF STRUCTURE cs_data TO FIELD-SYMBOL(<lv_cpf>).
    IF sy-subrc = 0 AND <lv_cpf> IS NOT INITIAL.
      CASE lv_mode.
        WHEN 'L'. CLEAR <lv_cpf>.
        WHEN 'G'. <lv_cpf> = generate_dummy_id( iv_prefix = `999` iv_original = CONV string( <lv_cpf> ) ).
      ENDCASE.
    ENDIF.

    ASSIGN COMPONENT 'ICNUM' OF STRUCTURE cs_data TO FIELD-SYMBOL(<lv_icnum>).
    IF sy-subrc = 0 AND <lv_icnum> IS NOT INITIAL.
      CASE lv_mode.
        WHEN 'L'. CLEAR <lv_icnum>.
        WHEN 'G'. <lv_icnum> = generate_dummy_id( iv_prefix = `999` iv_original = CONV string( <lv_icnum> ) ).
      ENDCASE.
    ENDIF.

    ASSIGN COMPONENT 'USRID_LONG' OF STRUCTURE cs_data TO FIELD-SYMBOL(<lv_email>).
    IF sy-subrc = 0 AND <lv_email> IS NOT INITIAL.
      <lv_email> = |employee{ cs_data-pernr }@company.com|.
    ENDIF.
  ENDMETHOD.

  METHOD generate_dummy_id.
    rv_dummy = |{ iv_prefix }{ sy-datum+2(6) }{ sy-uzeit(4) }|.
  ENDMETHOD.

  METHOD assign_fictitious_name.
    DATA: lv_index  TYPE i,
          lt_list   TYPE gtt_players,
          ls_person TYPE gty_player.

    " Determinar lista según el género del empleado (P0002-GESCH)
    " '1' = Masculino, '2' = Femenino
    IF cs_data-gesch = '2'.
      IF gt_female_names IS INITIAL.
        gt_female_names = get_female_names( ).
      ENDIF.
      lt_list = gt_female_names.
    ELSE.
      IF gt_players IS INITIAL.
        gt_players = get_players( ).
      ENDIF.
      lt_list = gt_players.
    ENDIF.

    IF lt_list IS INITIAL.
      RETURN.
    ENDIF.

    " Asignación determinística: mismo PERNR -> mismo personaje
    lv_index = ( iv_pernr MOD lines( lt_list ) ) + 1.

    READ TABLE lt_list INTO ls_person INDEX lv_index.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " Nombre y apellido
    ASSIGN COMPONENT 'VORNA' OF STRUCTURE cs_data TO FIELD-SYMBOL(<lv_vorna>).
    IF sy-subrc = 0.
      <lv_vorna> = ls_person-vorna.
    ENDIF.

    ASSIGN COMPONENT 'NACHN' OF STRUCTURE cs_data TO FIELD-SYMBOL(<lv_nachn>).
    IF sy-subrc = 0.
      <lv_nachn> = ls_person-nachn.
    ENDIF.

    " Nombre completo
    ASSIGN COMPONENT 'CNAME' OF STRUCTURE cs_data TO FIELD-SYMBOL(<lv_cname>).
    IF sy-subrc = 0.
      <lv_cname> = |{ ls_person-vorna } { ls_person-nachn }|.
    ENDIF.

    " Apodo / nombre de pila
    ASSIGN COMPONENT 'RUFNM' OF STRUCTURE cs_data TO FIELD-SYMBOL(<lv_rufnm>).
    IF sy-subrc = 0.
      <lv_rufnm> = ls_person-vorna.
    ENDIF.

    " Iniciales
    ASSIGN COMPONENT 'INITS' OF STRUCTURE cs_data TO FIELD-SYMBOL(<lv_inits>).
    IF sy-subrc = 0.
      <lv_inits> = |{ ls_person-vorna(1) }{ ls_person-nachn(1) }|.
    ENDIF.

    IF go_logger IS BOUND.
      go_logger->log_success(
        iv_pernr_tgt = iv_pernr
        iv_infty     = gc_infty
        iv_msg       = |Nombre ficticio asignado: { ls_person-vorna } { ls_person-nachn } (Género: { cs_data-gesch })|
      ).
    ENDIF.
  ENDMETHOD.

  METHOD get_players.
    rt_players = VALUE #(
      ( vorna = `Pelé`        nachn = `Nascimento`   )
      ( vorna = `Diego`       nachn = `Maradona`     )
      ( vorna = `Lionel`      nachn = `Messi`        )
      ( vorna = `Cristiano`   nachn = `Ronaldo`      )
      ( vorna = `Johan`       nachn = `Cruyff`       )
      ( vorna = `Franz`       nachn = `Beckenbauer`  )
      ( vorna = `Alfredo`     nachn = `Di Stéfano`   )
      ( vorna = `Zinedine`    nachn = `Zidane`       )
      ( vorna = `Ronaldo`     nachn = `Nazário`      )
      ( vorna = `Ronaldinho`  nachn = `Gaúcho`       )
      ( vorna = `George`      nachn = `Best`         )
      ( vorna = `Michel`      nachn = `Platini`      )
      ( vorna = `Garrincha`   nachn = `Dos Santos`   )
      ( vorna = `Eusébio`     nachn = `Da Silva`     )
      ( vorna = `Gerd`        nachn = `Müller`       )
      ( vorna = `Paolo`       nachn = `Maldini`      )
      ( vorna = `Roberto`     nachn = `Baggio`       )
      ( vorna = `Romário`     nachn = `De Souza`     )
      ( vorna = `Zico`        nachn = `Coimbra`      )
      ( vorna = `Lev`         nachn = `Yashin`       )
      ( vorna = `Ferenc`      nachn = `Puskás`       )
      ( vorna = `Bobby`       nachn = `Charlton`     )
      ( vorna = `Andrés`      nachn = `Iniesta`      )
      ( vorna = `Xavi`        nachn = `Hernández`    )
      ( vorna = `Iker`        nachn = `Casillas`     )
      ( vorna = `Thierry`     nachn = `Henry`        )
      ( vorna = `Kylian`      nachn = `Mbappé`       )
      ( vorna = `Neymar`      nachn = `Da Silva`     )
      ( vorna = `Luka`        nachn = `Modric`       )
      ( vorna = `Andrea`      nachn = `Pirlo`        )
      ( vorna = `Iván`        nachn = `Zamorano`     )
      ( vorna = `Marcelo`     nachn = `Salas`        )
      ( vorna = `Elías`       nachn = `Figueroa`     )
      ( vorna = `Carlos`      nachn = `Valderrama`   )
      ( vorna = `René`        nachn = `Higuita`      )
      ( vorna = `Radamel`     nachn = `Falcao`       )
      ( vorna = `Teófilo`     nachn = `Cubillas`     )
      ( vorna = `Enzo`        nachn = `Francescoli`  )
      ( vorna = `Hugo`        nachn = `Sánchez`      )
      ( vorna = `Kaká`        nachn = `Leite`        )
    ).
  ENDMETHOD.

  METHOD get_female_names.
    rt_female = VALUE #(
      ( vorna = `Shakira`     nachn = `Mebarak`      )
      ( vorna = `Beyoncé`     nachn = `Knowles`      )
      ( vorna = `Madonna`     nachn = `Ciccone`      )
      ( vorna = `Taylor`      nachn = `Swift`        )
      ( vorna = `Adele`       nachn = `Adkins`       )
      ( vorna = `Whitney`     nachn = `Houston`      )
      ( vorna = `Lady`        nachn = `Gaga`         )
      ( vorna = `Celine`      nachn = `Dion`         )
      ( vorna = `Mariah`      nachn = `Carey`        )
      ( vorna = `Aretha`      nachn = `Franklin`     )
      ( vorna = `Billie`      nachn = `Eilish`       )
      ( vorna = `Dua`         nachn = `Lipa`         )
      ( vorna = `Amy`         nachn = `Winehouse`    )
      ( vorna = `Rihanna`     nachn = `Fenty`        )
      ( vorna = `Selena`      nachn = `Gomez`        )
      ( vorna = `Karol`       nachn = `G`            )
      ( vorna = `Jennifer`    nachn = `Lopez`        )
      ( vorna = `Cher`        nachn = `Sarkisian`    )
      ( vorna = `Dolly`       nachn = `Parton`       )
      ( vorna = `Tina`        nachn = `Turner`       )
      ( vorna = `Gloria`      nachn = `Estefan`      )
      ( vorna = `Celia`       nachn = `Cruz`         )
      ( vorna = `Mercedes`    nachn = `Sosa`         )
      ( vorna = `Frida`       nachn = `Kahlo`        )
      ( vorna = `Marie`       nachn = `Curie`        )
      ( vorna = `Cleopatra`   nachn = `Filopátor`    )
      ( vorna = `Marilyn`     nachn = `Monroe`       )
      ( vorna = `Diana`       nachn = `Spencer`      )
      ( vorna = `Audrey`      nachn = `Hepburn`      )
      ( vorna = `Elizabeth`   nachn = `Taylor`       )
    ).
  ENDMETHOD.

ENDCLASS.
