// swiftlint:disable all
import Foundation
import SwiftAPIClient

{% if info.description %}
/** {{ info.description }} */
{% endif %}
public struct {{ options.name }} {

    {% if info.version %}
    public static let version = "{{ info.version }}"
    {% endif %}
    public var client: APIClient

    public init(client: APIClient) {
        self.client = client
    }
}
{% if servers %}
extension {{ options.name }} {

    public struct Server: Hashable {

        /// URL of the server
        public var url: URL

        public init(_ url: URL) {
            self.url = url
        }

        {% ifnot servers[0].variables %}
        public static var `default` = {{ options.name }}.Server.{{ servers[0].name }}
        {% endif %}
        {% for server in servers %}

        {% if server.description %}
        /** {{ server.description }} */
        {% endif %}
        {% if server.variables %}
        public static func {{ server.name }}({% for variable in server.variables %}{{ variable.name|replace:'-','_' }}: String = "{{ variable.defaultValue }}"{% ifnot forloop.last %}, {% endif %}{% endfor %}) -> {{ options.name }}.Server {
            var urlString = "{{ server.url }}"
            {% for variable in server.variables %}
            urlString = urlString.replacingOccurrences(of: {{'"{'}}{{variable.name}}{{'}"'}}, with: {{variable.name|replace:'-','_'}})
            {% endfor %}
            return {{ options.name }}.Server(URL(string: urlString)!)
        }
        {% else %}
        public static let {{ server.name }} = {{ options.name }}.Server(URL(string: "{{ server.url }}")!)
        {% endif %}
        {% endfor %}
    }
}

extension APIClient.Configs {

    /// {{ options.name }} server
    public var {{ options.name|lowerFirstWord }}Server: {{ options.name }}.Server{% if servers[0].variables %}?{% endif %} {
        get { self[\.{{ options.name|lowerFirstWord }}Server]{% ifnot servers[0].variables %} ?? .default{% endif %} }
        set { self[\.{{ options.name|lowerFirstWord }}Server] = newValue }
    }
}

{% else %}

// No servers defined in swagger. Documentation for adding them: https://swagger.io/specification/#schema
{% endif %}
{% if options.groupingType == "path" %}
{% macro pathTypeName path %}{{ path|basename|upperFirstLetter|replace:"{","By_"|replace:"}",""|swiftIdentifier:"pretty" }}{% endmacro %}
{% macro pathAsType path %}{% if path != "/" and path != "" %}{% call pathAsType path|dirname %}.{% call pathTypeName path %}{% endif %}{% endmacro %}

{% macro pathVarAndType path allPaths definedPath %}
{% set currentPath path|dirname %}
{% if path != "/" and path != "" %}
{% set _path %}|{{path}}|{% endset %}
{% if definedPath|contains:_path == false %}
extension {{ options.name }}{% call pathAsType currentPath %} {
    {% set name path|basename %}
    /// {{ path }}
    {% if name|contains:"{" %}
    public func callAsFunction(_ path: String) -> {% call pathTypeName path %} { {% call pathTypeName path %}(client: client(path)) }
    {% else %}
    public var {{ name|swiftIdentifier:"pretty"|lowerFirstWord|escapeReservedKeywords }}: {% call pathTypeName path %} { {% call pathTypeName path %}(client: client("{{name}}")) }
    {% endif %}
    public struct {% call pathTypeName path %} { public var client: APIClient }
}
{% set newDefinedPaths %}{{_path}}{{definedPath}}{% endset %}
{% call pathVarAndType currentPath allPaths newDefinedPaths %}
{% else %}
{% call pathVarAndType currentPath allPaths definedPath %}
{% endif %}
{% else %}
{% if allPaths != "/" and allPaths != "" %}
{% set path %}{{ allPaths|basename|replace:"$","/" }}{% endset %}
{% set newAllPaths allPaths|dirname %}
{% call pathVarAndType path newAllPaths definedPath %}
{% endif %}
{% endif %}
{% endmacro %}

{% map paths into pathArray %}{{maploop.item.path|replace:"/","$"}}{% endmap %}
{% set allPaths %}/{{ pathArray|join:"/" }}{% endset %}

{% set path %}{{ allPaths|basename|replace:"$","/" }}{% endset %}
{% call pathVarAndType path allPaths "" %}
{% elif options.groupingType == "tag" and tags %}
{% for tag in tags %}
extension {{ options.name }} {
    public var {{ tag|swiftIdentifier|lowerFirstLetter }}: {{ tag|swiftIdentifier }} { {{ tag|swiftIdentifier }}(client: client) }
    public struct {{ tag|swiftIdentifier }} { var client: APIClient }
}
{% endfor %}
{% endif %}
