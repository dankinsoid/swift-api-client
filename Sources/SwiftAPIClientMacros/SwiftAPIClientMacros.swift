#if canImport(SwiftCompilerPlugin)
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftOperators
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

@main
struct SwiftAPIClientMacrosPlugin: CompilerPlugin {
    
    let providingMacros: [Macro.Type] = [
        SwiftAPIClientCallMacro.self,
        SwiftAPIClientPathMacro.self
    ]
}

public struct SwiftAPIClientCallMacro: PeerMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard var funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError("@\(node.attributeName.description) macro can only be attached to a function")
        }

        guard
            let attribute = node.callAttribute(name: funcDecl.name)
        else {
            return []
        }
        var result: [DeclSyntax] = []

        if funcDecl.signature.effectSpecifiers == nil {
            funcDecl.signature.effectSpecifiers = FunctionEffectSpecifiersSyntax()
        }
        funcDecl.signature.effectSpecifiers?.throwsSpecifier = "throws"
        
        let isAsync = attribute.caller == "http" || funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        let callModifier = isAsync ? "try await " : "try "
        if isAsync {
            funcDecl.signature.effectSpecifiers?.asyncSpecifier = "async"
        }
        funcDecl.attributes = []

        var params = FunctionParameterListSyntax()
        if !attribute.pathArguments.isEmpty {
            params += attribute.pathArguments.map {
                "\(raw: $0.0): \(raw: $0.1), "
            }
        }
        var queryParams: ([String], [(String, String)]) = ([], [])
        var bodyParams: ([String], [(String, String)]) = ([], [])
        for var param in funcDecl.signature.parameterClause.parameters {
            
            let name = (param.secondName ?? param.firstName).trimmed.text
            if param.attributes.contains("Body"), attribute.method == ".get" {
                throw MacroError("Body parameter is not allowed with GET method")
            }
            try scanParameters(name: name, type: "Query", param: &param, into: &queryParams)
            try scanParameters(name: name, type: "Body", param: &param, into: &bodyParams)

            param.trailingComma = .commaToken()
            param.leadingTrivia = .newline
            params.append(param)
        }

        params += [
            "\nfileID: String = #fileID,",
            "\nline: UInt = #line"
        ]
        funcDecl.signature.parameterClause.rightParen.leadingTrivia = .newline
        funcDecl.signature.parameterClause.parameters = params
        var body = funcDecl.body ?? CodeBlockSyntax(statements: [])
        if body.statements.isEmpty {
            body.statements = ["\(raw: callModifier)client"]
        } else {
            body.statements.insert("try await ", at: body.statements.startIndex)
        }
        if !attribute.path.isEmpty {
            body.statements += ["    \(raw: pathString(path: attribute.path, arguments: attribute.pathArguments))"]
        }
        body.statements += ["    .method(\(raw: attribute.method))"]
        
        body.statements += queryParams.0.map { "    .query(\(raw: $0))" }
        if !queryParams.1.isEmpty {
            body.statements.append("    .query([\(raw: queryParams.1.map { "\"\($0.0)\": \($0.1)" }.joined(separator: ", "))])")
        }
        
        if bodyParams.0.count > 1 || !bodyParams.1.isEmpty && !bodyParams.0.isEmpty {
            throw MacroError("Body parameters merging is not supported yet")
        }
        if !bodyParams.1.isEmpty {
            body.statements.append("    .body([\(raw: bodyParams.1.map { "\"\($0.0)\": \($0.1)" }.joined(separator: ", "))])")
        } else if !bodyParams.0.isEmpty {
            body.statements.append("    .body(\(raw: bodyParams.0[0]))")
        }

        if let tuple = funcDecl.signature.returnClause?.type.as(TupleTypeSyntax.self) {
            let props: [(String, String)] = try tuple.elements.map {
                guard let label = ($0.firstName ?? $0.secondName) else {
                    throw MacroError("Tuple elements must have labels")
                }
                return (label.text, $0.type.trimmed.description)
            }
            let name = "\(funcDecl.name.text.firstUppercased)Response"
            funcDecl.signature.returnClause = ReturnClauseSyntax(type: TypeSyntax(stringLiteral: name))
            result.append(
                """
                public struct \(raw: name): Codable {
                    \(raw: props.map { "public var \($0.0): \($0.1)" }.joined(separator: "\n"))
                    public init(\(raw: props.map { "\($0.0): \($0.1)\($0.1.isOptional ? " = nil" : "")" }.joined(separator: ", "))) {
                        \(raw: props.map { "self.\($0.0) = \($0.0)" }.joined(separator: "\n"))
                    }
                }
                """
            )
        }
        
        var serializer = attribute.serializer ?? "decodable"
        if attribute.serializer == nil {
            let type = funcDecl.signature.returnClause?.type.trimmed.description ?? "Void"
            serializer = switch type {
            case "Void", "()": "void"
            case "String": "string"
            case "Data": "identity"
            case "JSON": "json"
            default: serializer
            }
        }
        body.statements += ["    .call(.\(raw: attribute.caller), as: Serializer.\(raw: serializer), fileID: fileID, line: line)"]
        funcDecl.body = body
        result.insert(DeclSyntax(funcDecl), at: 0)
        return result
    }
}

public struct SwiftAPIClientPathMacro: MemberMacro, MemberAttributeMacro, PeerMacro {

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard
            let funcDecl = member.as(FunctionDeclSyntax.self),
            funcDecl.attributes.contains(where: { $0.callAttribute(name: funcDecl.name) != nil })
        else { return [] }
        return ["@available(*, unavailable)", "@APICallFakeBuilder"]
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            return []
        }
        let accessControl = structDecl.modifiers.first(as: { $0.as(AccessorDeclSyntax.self) }).map {
            "\($0) "
        } ?? ""

        let path = path(node: node, name: structDecl.name)
        let pathArguments = pathArguments(path: path)
        let isVar = pathArguments.isEmpty
        let pathName = path.compactMap { $0.hasPrefix("{") ? nil : $0.firstUppercased }.joined().firstLowercased
        let name = path.count > pathArguments.count ? pathName : "callAsFunction"
        let args = pathArguments.map { "_ \($0.0): \($0.1)" }.joined(separator: ", ")

        var client = "client"
        if !path.isEmpty {
            client += pathString(path: path, arguments: pathArguments)
        }

        return [
            """
            /// /\(raw: path.joined(separator: "/"))
            \(raw: accessControl)\(raw: isVar ? "var" : "func") \(raw: name)\(raw: isVar ? ":" : "(\(args)) ->") \(raw: structDecl.name) {
                \(raw: structDecl.name)(client: \(raw: client))
            }
            """
        ]
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            return try structExpansion(of: node, providingMembersOf: structDecl, in: context)
        } else {
            throw MacroError("\(node.attributeName.description) macro can only be attached to a struct")
        }
    }

    private static func structExpansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: StructDeclSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        var result: [DeclSyntax] = [
            "public typealias Body<Value> = _APIParameterWrapper<Value>",
            "public typealias Query<Value> = _APIParameterWrapper<Value>",
            "public var client: APIClient"
        ]
        var hasRightInit = false
        var hasOtherInits = false

        let isPath = node.description.contains("Path")
        
        for member in declaration.memberBlock.members {
            if let initDecl = member.decl.as(InitializerDeclSyntax.self) {
                let params = initDecl.signature.parameterClause.parameters
                if
                    params.count == 1,
                    params.first?.firstName.trimmed.text == "client",
                    params.first?.type.trimmed.description == "APIClient"
                {
                    hasRightInit = true
                } else {
                    hasOtherInits = true
                }
            }
        }
        if !hasRightInit, !hasOtherInits {
            result.append(
                """
                \(raw: isPath ? "fileprivate" : "public") init(client: APIClient) {
                    self.client = client
                }
                """
            )
        } else if isPath, hasOtherInits {
            throw MacroError("Path struct must have init with only client: APIClient argument")
        }
        return result
    }
}

struct CallAttribute {
    let method: String
    let path: [String]
    let pathArguments: [(String, String, Int)]
    let caller: String
    let serializer: String?
}

extension AttributeListSyntax.Element {
    
    func callAttribute(name pathName: TokenSyntax) -> CallAttribute? {
        self.as(AttributeSyntax.self)?.callAttribute(name: pathName)
    }
}

extension AttributeSyntax {
    
    func callAttribute(name pathName: TokenSyntax) -> CallAttribute? {
        guard
            let name = attributeName.as(IdentifierTypeSyntax.self)?.name.trimmed.text
        else { return nil }
        let allowedNames: Set<String> = ["Call", "GET", "POST", "PUT", "DELETE", "PATCH"]
        guard allowedNames.contains(name) else {
            return nil
        }
        guard let arguments = arguments?.as(LabeledExprListSyntax.self) else {
            let pathItems = path(arguments: [], name: pathName)
            return CallAttribute(
                method: "." + name.lowercased(),
                path: pathItems,
                pathArguments: pathArguments(path: pathItems),
                caller: "http",
                serializer: nil
            )
        }
        var startIndex = arguments.startIndex
        let method: String
        if name == "Call" {
            method = arguments[startIndex].expression.trimmed.description
            startIndex = arguments.index(after: startIndex)
        } else {
            method = "." + name.lowercased()
        }
        let pathItems = path(arguments: arguments[startIndex...], name: pathName)
        return CallAttribute(
            method: method,
            path: pathItems,
            pathArguments: pathArguments(path: pathItems),
            caller: "http",
            serializer: nil
        )
    }
}

extension AttributeListSyntax {

    @discardableResult
    mutating func remove(_ name: String) -> Bool {
        if let i = firstIndex(where: { $0.as(AttributeSyntax.self)?.attributeName.trimmed.description == name }) {
            remove(at: i)
            return true
        }
        return false
    }
    
    func contains(_ name: String) -> Bool {
        contains(where: { $0.as(AttributeSyntax.self)?.attributeName.trimmed.description == name })
    }
}

private func pathArguments(
    path: [String]
) -> [(String, String, Int)] {
    let pathArgsIndicies = path.indices.filter {
        path[$0].hasPrefix("{") && path[$0].hasSuffix("}")
    }
    return pathArgsIndicies.map {
        let arg = path[$0].dropFirst().dropLast()
        let components = arg.split(separator: ":")
        let argName = components[0].trimmingCharacters(in: .alphanumerics.inverted)
        let argType = components.count > 1 ? components[1].trimmingCharacters(in: .alphanumerics.inverted) : "String"
        return (argName, argType, $0)
    }
}

private func path(
    node: AttributeSyntax,
    name: TokenSyntax
) -> [String] {
    path(arguments: node.arguments?.as(LabeledExprListSyntax.self), name: name)
}

private func path<C: Collection<LabeledExprListSyntax.Element>>(
    arguments: C?,
    name: TokenSyntax
) -> [String] {
    let path: [String] = arguments?.compactMap {
        $0.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
    } ?? []
    if path.isEmpty {
        return [name.trimmed.text.firstLowercased]
    } else {
        return path
            .flatMap { $0.components(separatedBy: ["/"]) }
            .filter { !$0.isEmpty }
    }
}

private func pathString(path: [String], arguments: [(String, String, Int)]) -> String {
    let string = path.enumerated().map { offset, item in
        if let arg = arguments.first(where: { $0.2 == offset }) {
            return arg.0
        } else {
            return "\"\(item)\""
        }
    }
    .joined(separator: ", ")
    return ".path(\(string))"
}

private func pathArguments(
    node: AttributeSyntax,
    name: TokenSyntax
) -> [(String, String, Int)] {
    pathArguments(path: path(node: node, name: name))
}

private func scanParameters(
    name: String,
    type: String,
    param: inout FunctionParameterListSyntax.Element,
    into list: inout ([String], [(String, String)])
) throws {
    if param.attributes.remove(type.firstUppercased) {
        list.1.append((name, name))
    }
    if param.firstName.trimmed.text.firstLowercased == type.firstLowercased {
        if let tuple = param.type.as(TupleTypeSyntax.self) {
            list.1 += try tuple.elements.map {
                guard let label = ($0.firstName ?? $0.secondName) else {
                    throw MacroError("Tuple elements must have labels")
                }
                return (label.text, "\(name).\(label.text)")
            }
        } else {
            list.0.append(name)
        }
    }
}

#endif
