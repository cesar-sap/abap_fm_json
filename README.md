JSON Adapter for ABAP Function Modules
======================================

Welcome to the JSON adapter for ABAP Function Modules!! (or adaptor)

This adapter was first published in SAP SCN blog (http://scn.sap.com/community/abap/connectivity/blog/2013/03/05/json-adapter-for-abap-function-modules). The blog remains its main reference and discussion place.

This adapter is specific to SAP ABAP systems. It should work on any SAP release from 7.0 onwards, however some slight modifications may be needed for older SP levels. 

The purpose of this adaptor is to allow calling ABAP function modules via HTTP and serializing the input and output in JSON format. This allows a very simple way to invoke ABAP functionality from HTML5 and AJAX or Jquery based applications. 

## How to install

*Many people are currently getting trouble to make SAPLink work. If you come accross problems, I have made available a transport request for direct import into an ABAP system in [transport/750](https://github.com/cesar-sap/abap_fm_json/tree/master/transport/750).

In order to install this you need [SAPLink](https://sap.assembla.com/spaces/saplink/wiki). First install SAPLink in your ABAP server following the [SAPLink installation instrucctions](http://wiki.scn.sap.com/wiki/display/ABAP/SAPlink+User+Documentation). Be sure to install the required [SAPLink plugins](https://www.assembla.com/spaces/saplink/wiki/SAPlink_plugin_list). To minimize trouble, I recommend your installing the [Nugget that contains all commonly used plugings](https://www.assembla.com/spaces/saplink-plugins/subversion/source/HEAD/build).

This adaptor works with any ABAP version from 7.0 onwards. I have tested it in 7.31, 7.40 and 7.50, which are the three releases where I can currently maintain it. If you are using any older release please contact me for indications.

As a rule, to make it work in any pre 7.31 release, you have to comment out all calls to the ABAP built-in JSON converter, that is, the calls to the methods SERIALIZE_ID and DESERIALIZE_ID in HANDLE_REQUEST and the code inside both methods. You cannot use them anyway in pre 7.31 releases. 


### ABAP Authorization 

The module includes an AUTHORITY_CHECK call to a custom authorization object named Z_JSON that validates if the user can access the function module. 

You must create and authorization object with the name Z_JSON and just one field named FNMANE as authorization objects are not yet transported with SAPLink. Use transaction SU21 for this.

The authorization object will be included in the corresponding user profile. An asterisk (\*) will allow the user to access all function modules. It is very recommended that any user that is going to access function modules through this adaptor has a profile with just the functions that he is allowed to access.


## How to invoke

### Create ICF service

You must create a service in ICF to make an endpoint for the adaptor. Here goes an example in transaction SICF:

![Define ICF service for the JSON adaptor](https://raw.githubusercontent.com/cesar-sap/abap_fm_json/master/SICF.jpg)

In this example, you will invoke the service using the following syntax:

`http(s)://your_abap_server:<port>/fmcall/<function_module_name>?<parameters>`

### Function module parameters

You can pass as GET query string parameters any of the function IMPORT parameters that are defined and single data types (not structures or tables).

In order to pass structures or tables to the function module, use any of the HTTP methods that support a content body (POST or PUT mainly).

Some parameters exist as standard. Most notably:

`format=<output_format>` set the format of the response. Valid formats are: json, xml, yaml, perl.

`lowercase=X` will show ABAP variable names in lower case.

`show_import_params=X` will include the IMPORT parameters in the response.

`callback=<callback_name>` wraps response in a JavaScript callback function (for [jsonp](http://stackoverflow.com/questions/3839966/can-anyone-explain-what-jsonp-is-in-layman-terms) enabled calls). 

### Supported output formats

The adaptor can produce output in the following formats: [JSON](http://www.json.org/), plain XML, [YAML 1.0](http://yaml.org/spec/1.0/), and [Perl](http://perldoc.perl.org/Data/Dumper.html) (which I did just for fun, but has itself shown to be quite useful in a number of occassions). 

Please note that the output format does not affect the input. The adaptor only supports input in JSON, and (if using the ABAP built-in transformation) in plain XML.

## Session and logon support

It is possible to activate ABAP session support for sequential calls to the adaptor (and thus running several calls in the same session context). Call the adaptor including a param action=start_session to activate it and action=end_session to finish it.

All ABAP logon methods are supported. Please configure the required one in SICF (see above).

## Cross Site requests

JSONP is supported. CORS support is planned.

## ABAP based or transformation based serializers

Originally this adaptor implemented pure ABAP based JSON to ABAP and ABAP to JSON serializers. Since [January 2013]() ABAP built-in transformations are available. The adaptor offers you the two options. The original pure ABAP serializers are activated by default. In order to use the built-in transformations, please comment out the corresponding lines in the HANDLE_REQUEST method.

## Comments

I welcome comments and suggestions for new ideas. Please feel free to contact me. 
