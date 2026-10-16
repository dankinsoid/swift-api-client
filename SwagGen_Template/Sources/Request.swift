{% if options.excludeTypes[type] == false %}

{% else %}
// swiftlint:disable all
import Foundation
import SwiftAPIClient

{% set tagType %}{% if tag %}{{ tag|swiftIdentifier }}{% endif %}{% endset %}
{% macro paramType param %}{% for enum in requestEnums %}{% if not enum.isGlobal and enum.enumName == param.type %}{{ type }}.{% endif %}{% endfor %}{{ param.optionalType }}{% endmacro %}
{% macro pathTypeName path %}{{ path|basename|upperFirstLetter|replace:"{","By_"|replace:"}",""|swiftIdentifier:"pretty" }}{% endmacro %}
{% if options.groupingType == "path" %}
{% macro pathPart path %}{% if path != "/" and path != "" %}{% call pathPart path|dirname %}.{% call pathTypeName path %}{% endif %}{% endmacro %}
extension {{ options.name }}{% call pathPart path %} {
{% elif options.groupingType == "tag" and tag %}
extension {{ options.name }}.{{ tagType }} {
{% else %}
extension {{ options.name }} {
{% endif %}

    /**
    {% if summary %}
    {{ summary }}

    {% endif %}
    {% if description %}
    {{ description }}

    {% endif %}
    **{{ method|uppercase }}** {{ path }}
    */
    {% set funcName %}{% if options.groupingType == "path" %}{{ method|lowercase|escapeReservedKeywords }}{% elif options.groupingType == "tag" and tag %}{{ type|replace:tagType,""|lowerFirstLetter }}{% else %}{{ type|lowerFirstLetter }}{% endif %}{% endset %}
    public func {{ funcName }}({% if options.groupingType != "path" %}{% for param in pathParams %}{{ param.name }}{% if param.name != param.value %} {{ param.value }}{% endif %}: {{ param.type }}, {% endfor %}{% endif %}{% for param in queryParams %}{{ param.name }}: {% call paramType param %}{% ifnot param.required %} = nil{% endif %}, {% endfor %}{% for param in headerParams %}{% if options.excludeHeaders[param.value] != true %}{{ param.name }}: {{ param.optionalType }}{% ifnot param.required %} = nil{% endif %}, {% endif %}{% endfor %}{% if body %}{{ body.name }}: {% for schema in requestSchemas %}{% if schema.type == body.type %}{{ type }}.{% endif %}{% endfor %}{{ body.optionalType }}{% ifnot body.required %} = nil{% endif %}, {% endif %}fileID: String = #fileID, line: UInt = #line, function: String = #function) async throws -> {% for schema in responseSchemas %}{% if schema.type == successType %}{{ type }}.{% endif %}{% endfor %}{{ successType|default:"Void" }} {
        try await client
            {% if options.groupingType != "path" %}
            .path("{{ path|replace:"{","\("|replace:"}",")" }}")
            {% endif %}
            .method(.{{ method|lowercase }})
            {% if queryParams %}
            .query([
                {% for param in queryParams %}
                "{{ param.value }}": {{ param.name }}{% ifnot forloop.last %},{% endif %}
                {% endfor %}
            ])
            {% endif %}
            {% if headerParams %}
            {% for param in headerParams %}
            {% if options.excludeHeaders[param.value] != true %}
            .header(HTTPField.Name("{{ param.value }}")!, {{ param.encodedValue }})
            {% endif %}
            {% endfor %}
            {% endif %}
            .auth(enabled: {% if securityRequirements %}true{% else %}false{% endif %})
            {% if body %}
            .body(body)
            {% endif %}
            .call(
                .http,
                as: .{% if successType == "String" %}string{% elif successType == "Data" or successType == "File" %}identity{% elif successType %}decodable{% else %}void{% endif %},
                fileID: fileID,
                line: line,
                function: function
            )
    }

    {% if requestEnums or requestSchemas %}
    public enum {{ type }} {
        {% for enum in requestEnums %}
        {% if not enum.isGlobal %}

        {% filter indent:8 %}{% include "Includes/Enum.stencil" enum %}{% endfilter %}
        {% endif %}
        {% endfor %}
        {% for schema in requestSchemas %}

        {% filter indent:8 %}{% include "Includes/Model.stencil" schema %}{% endfilter %}
        {% endfor %}
       
        {% for schema in responseSchemas %}
        
        {% filter indent:8 %}{% include "Includes/Model.stencil" schema %}{% endfilter %}
        
        {% endfor %}
        {% for enum in responseEnums %}
        {% if not enum.isGlobal %}

        {% filter indent:8 %}{% include "Includes/Enum.stencil" enum %}{% endfilter %}
        {% endif %}
        {% endfor %}
    }
    {% endif %}
}
{% endif %}
