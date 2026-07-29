*&---------------------------------------------------------------------*
*& ZCL_MCP_SERVER - SAP ABAP MCP Server
*& Exposes Function Modules as MCP Tools and Reports as MCP Resources
*& Inspired by ZCL_JSON_HANDLER (abap_fm_json)
*& Protocol: JSON-RPC 2.0 over HTTP (MCP spec 2024-11-05)
*&---------------------------------------------------------------------*
*& ICF Node setup: same as ZCL_JSON_HANDLER
*& Authorization object: Z_MCP_FM (field FMNAME, ACTVT)
*& Config tables: ZMCP_TOOLS, ZMCP_REPORTS (see comments below)
*&---------------------------------------------------------------------*

CLASS zcl_mcp_server DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_extension.

  PRIVATE SECTION.

    "--------------------------------------------------------------------
    " Types
    "--------------------------------------------------------------------
    TYPES:
      " Whitelisted Function Modules
      " Production: read from ZMCP_TOOLS (mandt/fm_name/description/active)
      BEGIN OF ty_tool,
        fm_name     TYPE funcname,
        description TYPE string,
      END OF ty_tool,
      tt_tools TYPE STANDARD TABLE OF ty_tool WITH KEY fm_name,

      " Whitelisted Reports
      " Production: read from ZMCP_REPORTS (mandt/program/variant/name/description/active)
      BEGIN OF ty_report,
        program     TYPE programm,
        variant     TYPE ralvariant,
        name        TYPE string,
        description TYPE string,
      END OF ty_report,
      tt_reports TYPE STANDARD TABLE OF ty_report WITH KEY program,

      " FM parameter descriptor
      BEGIN OF ty_fm_param,
        parameter TYPE string,
        typ       TYPE string,
        optional  TYPE abap_bool,
        kind      TYPE string,   " I=import E=export T=tables C=changing
      END OF ty_fm_param,
      tt_fm_params TYPE STANDARD TABLE OF ty_fm_param.

    "--------------------------------------------------------------------
    " Constants
    "--------------------------------------------------------------------
    CONSTANTS:
      gc_mcp_version TYPE string VALUE '2024-11-05',
      gc_server_name TYPE string VALUE 'SAP ABAP MCP Server',
      gc_server_ver  TYPE string VALUE '1.0.0',
      gc_uri_report  TYPE string VALUE 'sap://report/',
      gc_uri_job     TYPE string VALUE 'sap://job/'.

    "--------------------------------------------------------------------
    " Methods
    "--------------------------------------------------------------------
    METHODS:

      " --- Entry point ---
      parse_and_dispatch
        IMPORTING iv_body        TYPE string
        RETURNING VALUE(rv_json) TYPE string,

      " --- MCP protocol handlers ---
      handle_initialize
        IMPORTING iv_id          TYPE string
        RETURNING VALUE(rv_json) TYPE string,

      handle_tools_list
        IMPORTING iv_id          TYPE string
        RETURNING VALUE(rv_json) TYPE string,

      handle_tools_call
        IMPORTING
          iv_id          TYPE string
          iv_name        TYPE string
          iv_args        TYPE string
        RETURNING VALUE(rv_json) TYPE string,

      handle_resources_list
        IMPORTING iv_id          TYPE string
        RETURNING VALUE(rv_json) TYPE string,

      handle_resources_read
        IMPORTING
          iv_id          TYPE string
          iv_uri         TYPE string
          iv_params      TYPE string
        RETURNING VALUE(rv_json) TYPE string,

      " --- FM introspection and execution ---
      get_fm_interface
        IMPORTING  iv_fm_name      TYPE funcname
        RETURNING  VALUE(rt_params) TYPE tt_fm_params,

      get_fm_schema
        IMPORTING  iv_fm_name      TYPE funcname
        RETURNING  VALUE(rv_schema) TYPE string,

      call_fm_dynamic
        IMPORTING
          iv_fm_name     TYPE funcname
          iv_args        TYPE string
        RETURNING VALUE(rv_result) TYPE string
        RAISING   cx_sy_dyn_call_error,

      " --- Report submission and spool reading ---
      submit_report_job
        IMPORTING
          iv_program     TYPE programm
          iv_variant     TYPE ralvariant
          iv_params      TYPE string
        RETURNING VALUE(rv_job_uri) TYPE string,

      read_job_spool
        IMPORTING
          iv_job_name    TYPE btcjob
          iv_job_count   TYPE btcjobcnt
        RETURNING VALUE(rv_content) TYPE string,

      " --- Authorization ---
      check_authorization
        IMPORTING  iv_fm_name    TYPE funcname
        RETURNING  VALUE(rv_ok)  TYPE abap_bool,

      " --- JSON-RPC helpers ---
      json_result
        IMPORTING
          iv_id          TYPE string
          iv_result      TYPE string
        RETURNING VALUE(rv_json) TYPE string,

      json_error
        IMPORTING
          iv_id          TYPE string
          iv_code        TYPE i
          iv_message     TYPE string
        RETURNING VALUE(rv_json) TYPE string,

      " --- Whitelists ---
      tool_whitelist
        RETURNING VALUE(rt_tools)   TYPE tt_tools,

      report_whitelist
        RETURNING VALUE(rt_reports) TYPE tt_reports.

ENDCLASS.


CLASS zcl_mcp_server IMPLEMENTATION.

  "--------------------------------------------------------------------
  " IF_HTTP_EXTENSION~HANDLE_REQUEST
  " ICF entry point — validates HTTP method, dispatches JSON-RPC body
  "--------------------------------------------------------------------
  METHOD if_http_extension~handle_request.
    DATA: lv_body     TYPE string,
          lv_response TYPE string.

    server->response->set_header_field(
      name = 'Content-Type' value = 'application/json' ).

    IF server->request->get_method( ) <> 'POST'.
      server->response->set_status( code = 405 reason = 'Method Not Allowed' ).
      server->response->set_cdata( '{"error":"POST required"}' ).
      RETURN.
    ENDIF.

    lv_body     = server->request->get_cdata( ).
    lv_response = parse_and_dispatch( lv_body ).

    server->response->set_status( code = 200 reason = 'OK' ).
    server->response->set_cdata( lv_response ).
  ENDMETHOD.


  "--------------------------------------------------------------------
  " PARSE_AND_DISPATCH
  " Parses JSON-RPC 2.0 envelope and routes to the correct handler.
  " Keeps parsing minimal — only method, id, and params sub-object.
  "--------------------------------------------------------------------
  METHOD parse_and_dispatch.
    DATA: lv_method  TYPE string,
          lv_id      TYPE string,
          lv_params  TYPE string,
          lv_name    TYPE string,
          lv_args    TYPE string,
          lv_uri     TYPE string.

    FIND REGEX '"method"\s*:\s*"([^"]+)"'
      IN iv_body SUBMATCHES lv_method.
    FIND REGEX '"id"\s*:\s*"?(\w+)"?'
      IN iv_body SUBMATCHES lv_id.

    " Extract params block as raw JSON substring
    FIND REGEX '"params"\s*:\s*(\{.*\})'
      IN iv_body SUBMATCHES lv_params.

    CASE lv_method.

      WHEN 'initialize'.
        rv_response = handle_initialize( lv_id ).

      WHEN 'tools/list'.
        rv_response = handle_tools_list( lv_id ).

      WHEN 'tools/call'.
        FIND REGEX '"name"\s*:\s*"([^"]+)"'
          IN lv_params SUBMATCHES lv_name.
        FIND REGEX '"arguments"\s*:\s*(\{[^}]*\})'
          IN lv_params SUBMATCHES lv_args.
        rv_response = handle_tools_call(
          iv_id   = lv_id
          iv_name = lv_name
          iv_args = lv_args ).

      WHEN 'resources/list'.
        rv_response = handle_resources_list( lv_id ).

      WHEN 'resources/read'.
        FIND REGEX '"uri"\s*:\s*"([^"]+)"'
          IN lv_params SUBMATCHES lv_uri.
        rv_response = handle_resources_read(
          iv_id     = lv_id
          iv_uri    = lv_uri
          iv_params = lv_params ).

      WHEN OTHERS.
        rv_response = json_error(
          iv_id      = lv_id
          iv_code    = -32601
          iv_message = 'Method not found' ).
    ENDCASE.
  ENDMETHOD.


  "--------------------------------------------------------------------
  " HANDLE_INITIALIZE
  " MCP handshake — returns server capabilities
  "--------------------------------------------------------------------
  METHOD handle_initialize.
    DATA lv_result TYPE string.

    CONCATENATE
      '{"protocolVersion":"' gc_mcp_version '",'
      '"serverInfo":{"name":"' gc_server_name '","version":"' gc_server_ver '"},'
      '"capabilities":{"tools":{},"resources":{}}}'
      INTO lv_result.

    rv_json = json_result( iv_id = iv_id iv_result = lv_result ).
  ENDMETHOD.


  "--------------------------------------------------------------------
  " HANDLE_TOOLS_LIST
  " Returns all whitelisted FMs as MCP tool definitions with JSON Schema
  "--------------------------------------------------------------------
  METHOD handle_tools_list.
    DATA: lt_tools   TYPE tt_tools,
          lv_tools   TYPE string,
          lv_schema  TYPE string,
          lv_entry   TYPE string,
          lv_sep     TYPE string.

    lt_tools = tool_whitelist( ).

    LOOP AT lt_tools INTO DATA(ls_tool).
      lv_schema = get_fm_schema( ls_tool-fm_name ).
      CONCATENATE
        '{"name":"' ls_tool-fm_name '",'
        '"description":"' ls_tool-description '",'
        '"inputSchema":' lv_schema '}'
        INTO lv_entry.
      CONCATENATE lv_tools lv_sep lv_entry INTO lv_tools.
      lv_sep = ','.
    ENDLOOP.

    rv_json = json_result(
      iv_id     = iv_id
      iv_result = |{ '{"tools":[' }{ lv_tools }{ ']}' }| ).
  ENDMETHOD.


  "--------------------------------------------------------------------
  " GET_FM_INTERFACE
  " Reads FM parameter list via RPY_FUNCTIONMODULE_READ
  "--------------------------------------------------------------------
  METHOD get_fm_interface.
    TYPES:
      BEGIN OF ty_rpy_fupa,
        parameter   TYPE string,
        typ         TYPE string,
        optional    TYPE c LENGTH 1,
      END OF ty_rpy_fupa.

    DATA: lt_import   TYPE STANDARD TABLE OF rpy_fupa,
          lt_export   TYPE STANDARD TABLE OF rpy_fupa,
          lt_tables   TYPE STANDARD TABLE OF rpy_fupa,
          lt_changing TYPE STANDARD TABLE OF rpy_fupa,
          lt_except   TYPE STANDARD TABLE OF rpy_fues.

    CALL FUNCTION 'RPY_FUNCTIONMODULE_READ'
      EXPORTING
        functionname     = iv_fm_name
      TABLES
        import_parameter = lt_import
        export_parameter = lt_export
        tables_parameter = lt_tables
        changing_paramtr = lt_changing
        exception_list   = lt_except
      EXCEPTIONS
        OTHERS           = 1.

    IF sy-subrc <> 0. RETURN. ENDIF.

    LOOP AT lt_import INTO DATA(ls_p).
      INSERT VALUE ty_fm_param(
        parameter = ls_p-parameter
        typ       = ls_p-typ
        optional  = COND #( WHEN ls_p-optional = 'X' THEN abap_true ELSE abap_false )
        kind      = 'I' ) INTO TABLE rt_params.
    ENDLOOP.
    LOOP AT lt_export INTO ls_p.
      INSERT VALUE ty_fm_param(
        parameter = ls_p-parameter typ = ls_p-typ
        optional  = abap_true kind = 'E' ) INTO TABLE rt_params.
    ENDLOOP.
    LOOP AT lt_tables INTO ls_p.
      INSERT VALUE ty_fm_param(
        parameter = ls_p-parameter typ = ls_p-typ
        optional  = abap_true kind = 'T' ) INTO TABLE rt_params.
    ENDLOOP.
    LOOP AT lt_changing INTO ls_p.
      INSERT VALUE ty_fm_param(
        parameter = ls_p-parameter typ = ls_p-typ
        optional  = COND #( WHEN ls_p-optional = 'X' THEN abap_true ELSE abap_false )
        kind      = 'C' ) INTO TABLE rt_params.
    ENDLOOP.
  ENDMETHOD.


  "--------------------------------------------------------------------
  " GET_FM_SCHEMA
  " Builds a JSON Schema object for the FM's import parameters
  "--------------------------------------------------------------------
  METHOD get_fm_schema.
    DATA: lt_params   TYPE tt_fm_params,
          lv_props    TYPE string,
          lv_required TYPE string,
          lv_jtype    TYPE string,
          lv_psep     TYPE string,
          lv_rsep     TYPE string.

    lt_params = get_fm_interface( iv_fm_name ).

    LOOP AT lt_params INTO DATA(ls_p) WHERE kind = 'I'.
      " Map basic ABAP types to JSON Schema types
      lv_jtype = SWITCH #( ls_p-typ
        WHEN 'I' OR 'INT8' OR 'INT1' OR 'INT2' THEN 'integer'
        WHEN 'F' OR 'P' OR 'DECFLOAT16' OR 'DECFLOAT34' THEN 'number'
        WHEN 'XSTRING' THEN 'string'
        ELSE 'string' ).

      CONCATENATE lv_props lv_psep
        '"' ls_p-parameter '":{"type":"' lv_jtype
        '","description":"' ls_p-parameter '"}'
        INTO lv_props.
      lv_psep = ','.

      IF ls_p-optional = abap_false.
        CONCATENATE lv_required lv_rsep '"' ls_p-parameter '"'
          INTO lv_required.
        lv_rsep = ','.
      ENDIF.
    ENDLOOP.

    IF lv_required IS NOT INITIAL.
      CONCATENATE
        '{"type":"object","properties":{' lv_props '},'
        '"required":[' lv_required ']}'
        INTO rv_schema.
    ELSE.
      CONCATENATE
        '{"type":"object","properties":{' lv_props '}}'
        INTO rv_schema.
    ENDIF.
  ENDMETHOD.


  "--------------------------------------------------------------------
  " HANDLE_TOOLS_CALL
  " Authorization check → dynamic FM call → serialize result
  "--------------------------------------------------------------------
  METHOD handle_tools_call.
    IF check_authorization( iv_name ) = abap_false.
      rv_json = json_error(
        iv_id      = iv_id
        iv_code    = -32603
        iv_message = |Not authorized: { iv_name }| ).
      RETURN.
    ENDIF.

    TRY.
        DATA(lv_result) = call_fm_dynamic(
          iv_fm_name = iv_name
          iv_args    = iv_args ).

        DATA lv_content TYPE string.
        CONCATENATE
          '{"content":[{"type":"text","text":' lv_result '}]}'
          INTO lv_content.

        rv_json = json_result( iv_id = iv_id iv_result = lv_content ).

      CATCH cx_sy_dyn_call_error INTO DATA(lx_err).
        rv_json = json_error(
          iv_id      = iv_id
          iv_code    = -32603
          iv_message = lx_err->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  "--------------------------------------------------------------------
  " CALL_FM_DYNAMIC
  " Builds abap_func_parmbind_tab from JSON args and calls FM dynamically
  " Uses CL_ABAP_TYPEDESCR for runtime type creation per parameter
  "--------------------------------------------------------------------
  METHOD call_fm_dynamic.
    DATA: lt_params    TYPE tt_fm_params,
          lt_pbind     TYPE abap_func_parmbind_tab,
          lt_ebind     TYPE abap_func_excpbind_tab,
          ls_pbind     TYPE abap_func_parmbind,
          ls_ebind     TYPE abap_func_excpbind,
          lv_value     TYPE string,
          lv_result    TYPE string,
          lv_sep       TYPE string.

    lt_params = get_fm_interface( iv_fm_name ).

    " Bind import parameters — deserialize from JSON args
    LOOP AT lt_params INTO DATA(ls_p) WHERE kind = 'I' OR kind = 'C'.
      FIND REGEX |"{ ls_p-parameter }"\s*:\s*"?([^",\}\s]+)"?|
        IN iv_args SUBMATCHES lv_value.

      TRY.
          DATA(lo_type) = cl_abap_typedescr=>describe_by_name( ls_p-typ ).
          CREATE DATA ls_pbind-value TYPE HANDLE lo_type.
          ASSIGN ls_pbind-value->* TO FIELD-SYMBOL(<fv>).
          IF sy-subrc = 0 AND lv_value IS NOT INITIAL.
            <fv> = lv_value.
          ENDIF.
        CATCH cx_sy_create_data_error.
          " Fall back to string for unknown types
          CREATE DATA ls_pbind-value TYPE string.
          ASSIGN ls_pbind-value->* TO <fv>.
          <fv> = lv_value.
      ENDTRY.

      ls_pbind-name = ls_p-parameter.
      ls_pbind-kind = SWITCH #( ls_p-kind
        WHEN 'I' THEN abap_func_exporting
        WHEN 'C' THEN abap_func_changing ).
      INSERT ls_pbind INTO TABLE lt_pbind.
    ENDLOOP.

    " Bind export and table parameters — empty containers for results
    LOOP AT lt_params INTO ls_p WHERE kind = 'E' OR kind = 'T'.
      TRY.
          lo_type = cl_abap_typedescr=>describe_by_name( ls_p-typ ).
          CREATE DATA ls_pbind-value TYPE HANDLE lo_type.
        CATCH cx_sy_create_data_error.
          CREATE DATA ls_pbind-value TYPE string.
      ENDTRY.
      ls_pbind-name = ls_p-parameter.
      ls_pbind-kind = SWITCH #( ls_p-kind
        WHEN 'E' THEN abap_func_importing
        WHEN 'T' THEN abap_func_tables ).
      INSERT ls_pbind INTO TABLE lt_pbind.
    ENDLOOP.

    " Standard exception binding
    ls_ebind-name = 'OTHERS'. ls_ebind-value = 1.
    INSERT ls_ebind INTO TABLE lt_ebind.

    " Execute
    CALL FUNCTION iv_fm_name
      PARAMETER-TABLE lt_pbind
      EXCEPTION-TABLE lt_ebind.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_sy_dyn_call_error.
    ENDIF.

    " Serialize export/table/changing results to JSON via CL_JSON
    lv_result = '{'.
    LOOP AT lt_pbind INTO ls_pbind
      WHERE kind = abap_func_importing
         OR kind = abap_func_tables
         OR kind = abap_func_changing.
      ASSIGN ls_pbind-value->* TO FIELD-SYMBOL(<res>).
      DATA(lv_serialized) = cl_json=>serialize( data = <res> compress = abap_true ).
      CONCATENATE lv_result lv_sep '"' ls_pbind-name '":' lv_serialized
        INTO lv_result.
      lv_sep = ','.
    ENDLOOP.
    CONCATENATE lv_result '}' INTO lv_result.

    rv_result = lv_result.
  ENDMETHOD.


  "--------------------------------------------------------------------
  " HANDLE_RESOURCES_LIST
  " Returns whitelisted reports as MCP resources
  "--------------------------------------------------------------------
  METHOD handle_resources_list.
    DATA: lt_reports   TYPE tt_reports,
          lv_resources TYPE string,
          lv_entry     TYPE string,
          lv_sep       TYPE string.

    lt_reports = report_whitelist( ).

    LOOP AT lt_reports INTO DATA(ls_report).
      CONCATENATE
        '{"uri":"sap://report/' ls_report-program '",'
        '"name":"' ls_report-name '",'
        '"description":"' ls_report-description '",'
        '"mimeType":"application/json"}'
        INTO lv_entry.
      CONCATENATE lv_resources lv_sep lv_entry INTO lv_resources.
      lv_sep = ','.
    ENDLOOP.

    rv_json = json_result(
      iv_id     = iv_id
      iv_result = |{ '{"resources":[' }{ lv_resources }{ ']}' }| ).
  ENDMETHOD.


  "--------------------------------------------------------------------
  " HANDLE_RESOURCES_READ
  " URI dispatch:
  "   sap://report/PROGRAM         -> submit job, return job URI
  "   sap://report/PROGRAM/VARIANT -> submit with variant
  "   sap://job/JOBNAME/JOBNUMBER  -> read spool of completed job
  "--------------------------------------------------------------------
  METHOD handle_resources_read.
    DATA: lv_seg1    TYPE string,
          lv_seg2    TYPE string,
          lv_seg3    TYPE string,
          lv_uri_work TYPE string.

    " Strip scheme and split path segments
    lv_uri_work = iv_uri.
    REPLACE 'sap://' IN lv_uri_work WITH ''.
    SPLIT lv_uri_work AT '/' INTO lv_seg1 lv_seg2 lv_seg3.

    CASE lv_seg1.

      WHEN 'report'.
        " Submit the report as a background job
        DATA(lv_job_uri) = submit_report_job(
          iv_program = lv_seg2
          iv_variant = lv_seg3
          iv_params  = iv_params ).

        DATA lv_submitted TYPE string.
        CONCATENATE
          '{"contents":[{"uri":"' lv_job_uri '",'
          '"mimeType":"application/json",'
          '"text":"{\"status\":\"submitted\",\"jobUri\":\"' lv_job_uri '\"}"'
          '}]}'
          INTO lv_submitted.

        rv_json = json_result( iv_id = iv_id iv_result = lv_submitted ).

      WHEN 'job'.
        " Read spool of a completed or running job
        DATA(lv_content) = read_job_spool(
          iv_job_name  = lv_seg2
          iv_job_count = lv_seg3 ).

        " Escape content for JSON embedding
        REPLACE ALL OCCURRENCES OF '"' IN lv_content WITH '\"'.
        REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline
          IN lv_content WITH '\n'.

        DATA lv_spool_result TYPE string.
        CONCATENATE
          '{"contents":[{"uri":"' iv_uri '",'
          '"mimeType":"text/plain",'
          '"text":"' lv_content '"'
          '}]}'
          INTO lv_spool_result.

        rv_json = json_result( iv_id = iv_id iv_result = lv_spool_result ).

      WHEN OTHERS.
        rv_json = json_error(
          iv_id      = iv_id
          iv_code    = -32602
          iv_message = |Unknown URI: { iv_uri }| ).
    ENDCASE.
  ENDMETHOD.


  "--------------------------------------------------------------------
  " SUBMIT_REPORT_JOB
  " Opens a background job, submits the report program, closes immediately.
  " Returns a sap://job/... URI for subsequent resources/read polling.
  "--------------------------------------------------------------------
  METHOD submit_report_job.
    DATA: lv_jobname  TYPE btcjob VALUE 'ZMCP_REPORT',
          lv_jobcount TYPE btcjobcnt.

    CALL FUNCTION 'JOB_OPEN'
      EXPORTING
        jobname          = lv_jobname
      IMPORTING
        jobcount         = lv_jobcount
      EXCEPTIONS
        cant_create_job  = 1
        OTHERS           = 2.

    IF sy-subrc <> 0.
      rv_job_uri = 'sap://error/job_open_failed'. RETURN.
    ENDIF.

    IF iv_variant IS NOT INITIAL.
      SUBMIT (iv_program)
        USING SELECTION-SET iv_variant
        VIA JOB lv_jobname NUMBER lv_jobcount
        AND RETURN.
    ELSE.
      SUBMIT (iv_program)
        VIA JOB lv_jobname NUMBER lv_jobcount
        AND RETURN.
    ENDIF.

    CALL FUNCTION 'JOB_CLOSE'
      EXPORTING
        jobname          = lv_jobname
        jobcount         = lv_jobcount
        strtimmed        = abap_true
      EXCEPTIONS
        OTHERS           = 1.

    CONCATENATE gc_uri_job lv_jobname '/' lv_jobcount
      INTO rv_job_uri.
  ENDMETHOD.


  "--------------------------------------------------------------------
  " READ_JOB_SPOOL
  " Retrieves spool output for a completed background job.
  " Returns raw text; caller escapes for JSON embedding.
  "--------------------------------------------------------------------
  METHOD read_job_spool.
    DATA: lt_spool  TYPE STANDARD TABLE OF tsp_line,
          lv_line   TYPE string.

    CALL FUNCTION 'RSPO_RETURN_ABAP_SPOOLJOB'
      EXPORTING
        jobname  = iv_job_name
        jobcount = iv_job_count
      TABLES
        buffer   = lt_spool
      EXCEPTIONS
        OTHERS   = 1.

    LOOP AT lt_spool INTO DATA(ls_line).
      CONCATENATE rv_content ls_line-line cl_abap_char_utilities=>newline
        INTO rv_content.
    ENDLOOP.
  ENDMETHOD.


  "--------------------------------------------------------------------
  " CHECK_AUTHORIZATION
  " Uses Z_MCP_FM authority object (field FMNAME).
  " Create this object in SU21 with fields: FMNAME (funcname), ACTVT.
  "--------------------------------------------------------------------
  METHOD check_authorization.
    AUTHORITY-CHECK OBJECT 'Z_MCP_FM'
      ID 'FMNAME' FIELD iv_fm_name
      ID 'ACTVT'  FIELD '16'.
    rv_ok = COND #( WHEN sy-subrc = 0 THEN abap_true ELSE abap_false ).
  ENDMETHOD.


  "--------------------------------------------------------------------
  " JSON_RESULT / JSON_ERROR
  " JSON-RPC 2.0 response envelope helpers
  "--------------------------------------------------------------------
  METHOD json_result.
    CONCATENATE
      '{"jsonrpc":"2.0","id":"' iv_id '","result":' iv_result '}'
      INTO rv_json.
  ENDMETHOD.

  METHOD json_error.
    DATA lv_code TYPE string.
    lv_code = iv_code.
    CONCATENATE
      '{"jsonrpc":"2.0","id":"' iv_id '",'
      '"error":{"code":' lv_code ',"message":"' iv_message '"}}'
      INTO rv_json.
  ENDMETHOD.


  "--------------------------------------------------------------------
  " TOOL_WHITELIST
  " Hardcoded defaults — replace with SELECT from ZMCP_TOOLS in production
  "--------------------------------------------------------------------
  METHOD tool_whitelist.
    rt_tools = VALUE tt_tools(
      ( fm_name     = 'BAPI_CUSTOMER_GETDETAIL'
        description = 'Retrieve customer master data by customer number' )
      ( fm_name     = 'BAPI_SALESORDER_GETLIST'
        description = 'List sales orders for a customer within a date range' )
      ( fm_name     = 'BAPI_MATERIAL_GET_ALL'
        description = 'Get material master data including plant and storage info' )
      ( fm_name     = 'BAPI_PO_GETITEMS'
        description = 'Retrieve purchase order items and their status' )
      ( fm_name     = 'BAPI_OUTB_DELIVERY_GET_LIST'
        description = 'List outbound deliveries by ship-to party or date' )
      ( fm_name     = 'BAPI_ACC_GL_POSTING_GET_DETAIL'
        description = 'Get general ledger posting details by document number' )
    ).
  ENDMETHOD.


  "--------------------------------------------------------------------
  " REPORT_WHITELIST
  " Hardcoded defaults — replace with SELECT from ZMCP_REPORTS in production
  "--------------------------------------------------------------------
  METHOD report_whitelist.
    rt_reports = VALUE tt_reports(
      ( program     = 'Z_FI_OPEN_ITEMS'
        variant     = 'MCP_DEFAULT'
        name        = 'Open Items'
        description = 'Customer open items by due date — AR aging' )
      ( program     = 'Z_SD_DELIVERIES'
        variant     = 'MCP_DEFAULT'
        name        = 'Pending Deliveries'
        description = 'Outbound deliveries pending goods issue or shipment' )
      ( program     = 'Z_MM_STOCK'
        variant     = 'MCP_DEFAULT'
        name        = 'Stock Overview'
        description = 'Material stock levels by plant and storage location' )
      ( program     = 'Z_HR_HEADCOUNT'
        variant     = 'MCP_DEFAULT'
        name        = 'Headcount Report'
        description = 'Active headcount by org unit and employment type' )
    ).
  ENDMETHOD.

ENDCLASS.


*&---------------------------------------------------------------------*
*& DEPLOYMENT NOTES
*&---------------------------------------------------------------------*
*& 1. ICF NODE
*&    Create under /default_host/sap/zmcp
*&    Handler class: ZCL_MCP_SERVER
*&    Authentication: as required (Basic / SNC / cert)
*&
*& 2. AUTHORIZATION OBJECT Z_MCP_FM
*&    Create in SU21:
*&      Field FMNAME  TYPE FUNCNAME  (function module name)
*&      Field ACTVT   TYPE ACTVT     (use activity 16 = execute)
*&    Assign to roles per FM / user as needed
*&
*& 3. CONFIG TABLES (optional, replaces hardcoded whitelists)
*&
*&    ZMCP_TOOLS:
*&      MANDT       TYPE MANDT
*&      FM_NAME     TYPE FUNCNAME
*&      DESCRIPTION TYPE STRING
*&      ACTIVE      TYPE ABAP_BOOL
*&
*&    ZMCP_REPORTS:
*&      MANDT       TYPE MANDT
*&      PROGRAM     TYPE PROGRAMM
*&      VARIANT     TYPE RALVARIANT
*&      NAME        TYPE STRING
*&      DESCRIPTION TYPE STRING
*&      ACTIVE      TYPE ABAP_BOOL
*&
*& 4. MCP CLIENT CONFIGURATION
*&    Endpoint: https://<host>/sap/zmcp
*&    Transport: HTTP (streamable HTTP or SSE can be added later)
*&    Auth: as configured on ICF node
*&
*& 5. KNOWN LIMITATIONS IN THIS VERSION
*&    - params regex extraction is simplistic; consider CL_SXML_PARSER
*&      for robust nested JSON parsing in production
*&    - SSE (Server-Sent Events) transport not yet implemented
*&    - ALV interception for structured report output not yet implemented
*&      (see note below on ALV approach)
*&
*& 6. ALV STRUCTURED OUTPUT (future enhancement)
*&    Instead of reading raw spool text, intercept ALV output:
*&    - Register a CL_SALV_TABLE instance via CALL METHOD with custom
*&      display class that captures the internal table before rendering
*&    - Serialize via CL_JSON and return as application/json resource
*&    This gives the agent clean tabular data instead of formatted text
*&---------------------------------------------------------------------*
