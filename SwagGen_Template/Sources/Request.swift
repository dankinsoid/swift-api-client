{% if options.excludeTypes[type] == false %}

{% else %}
// swiftlint:disable all
import Foundation
import SwiftAPIClient

{% set tagType %}{{ tag|swiftIdentifier }}{% endset %}
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
    public func {{ funcName }}({% if options.groupingType != "path" %}{% for param in pathParams %}{{ param.name }}: {{ param.type }}, {% endfor %}{% endif %}{% for param in queryParams %}{{ param.name }}: {{ param.optionalType }}{% ifnot param.required %} = nil{% endif %}, {% endfor %}{% for param in headerParams %}{% if options.excludeHeaders[param.value] != true %}{{ param.name }}: {{ param.optionalType }}{% ifnot param.required %} = nil{% endif %}, {% endif %}{% endfor %}{% if body %}{{ body.name }}: {{ body.optionalType }}{% ifnot body.required %} = nil{% endif %}, {% endif %}fileID: String = #fileID, line: UInt = #line) async throws -> {{ successType|default:"Void" }} {
        try await client
            {% if options.groupingType != "path" %}
            .path("{{ path|replace:"{","\("|replace:"}",")" }}")
            {% endif %}
            .method(.{{ method|lowercase }})
            {% if queryParams %}
            .query([
                {% for param in queryParams %}
                "{{ param.value }}": {{ param.value }}{% ifnot forloop.last %},{% endif %}
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
                line: line
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

        {% filter indent:12 %}{% include "Includes/Model.stencil" schema %}{% endfilter %}
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
