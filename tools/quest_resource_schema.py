"""Read literal GDScript owner shapes without executing game code.

Only literal containers, true/false/null, Vector3 coordinates, and a named
preload's initial() are admitted. Unknown syntax fails the build closed.
"""
import ast
import re
from pathlib import Path


def literal(expression, path):
    path = Path(path)
    class Values(ast.NodeTransformer):
        def visit_Name(self, node):
            values = {'true': True, 'false': False, 'null': None}
            if node.id not in values:
                raise ValueError(f'{path.name}: nonliteral name {node.id}')
            return ast.copy_location(ast.Constant(values[node.id]), node)
        def visit_Call(self, node):
            if isinstance(node.func, ast.Name) and node.func.id == 'Vector3':
                if len(node.args) != 3 or node.keywords:
                    raise ValueError('Invalid source coordinate')
                return ast.Constant(None)  # Only the dictionary's target keys are needed.
            if isinstance(node.func, ast.Attribute) and node.func.attr == 'initial' and isinstance(node.func.value, ast.Name) and not node.args and not node.keywords:
                alias = node.func.value.id
                match = re.search(r'^const\s+'+re.escape(alias)+r'\s*(?::=|=)\s*preload\("res://scripts/lol2/([^"\n]+)"\)', path.read_text(), re.M)
                if match:
                    value = initial(path.parent / match[1])
                    return ast.parse(repr(value), mode='eval').body
            raise ValueError(f'{path.name}: unqualified shape call')
    tree = Values().visit(ast.parse(expression, mode='eval'))
    return ast.literal_eval(tree)


def returned_dictionary(path, function):
    text = Path(path).read_text()
    match = re.search(r'^(?:static\s+)?func\s+'+re.escape(function)+r'\(', text, re.M)
    if not match:
        raise ValueError(f'{path}: missing {function} shape')
    following = re.search(r'^(?:static\s+)?func\s+', text[match.end():], re.M)
    body = text[match.start():match.end()+following.start()] if following else text[match.start():]
    for line in body.splitlines():
        result = re.search(r'\breturn\s+(\{.*\})\s*(?:#.*)?$', line)
        if result:
            value = literal(result[1], path)
            if not isinstance(value, dict):
                raise ValueError('Owner shape is not a dictionary')
            return value
    raise ValueError(f'{path}: {function} has no qualified literal dictionary')


def initial(path):
    return returned_dictionary(path, 'initial')


def resolve(shapes, path):
    value = shapes
    for field in path:
        if not isinstance(value, dict) or field not in value:
            raise ValueError('Unknown quest policy state path: '+'.'.join(path))
        value = value[field]
    return value
