class GuestConfig {
  const GuestConfig({
    required this.values,
    required this.editSchema,
  });

  final Map<String, String> values;
  final GuestConfigEditSchema editSchema;

  bool isEditable(String key) => editSchema.isEditable(key);
}

class GuestConfigEditSchema {
  const GuestConfigEditSchema({
    required this.parameters,
    required this.isAvailable,
  });

  const GuestConfigEditSchema.unavailable()
    : parameters = const <String>{},
      isAvailable = false;

  factory GuestConfigEditSchema.fromOptions(Object? data) {
    final parameters = <String>{};
    var foundPutSchema = false;

    void collectParameters(Object? methodData) {
      if (methodData is! Map) {
        return;
      }
      final methodParameters = methodData['parameters'];
      if (methodParameters is! Map) {
        return;
      }
      final properties = methodParameters['properties'];
      if (properties is! Map) {
        return;
      }
      foundPutSchema = true;
      parameters.addAll(properties.keys.map((key) => key.toString()));
    }

    void collectPutSchemas(Object? value) {
      if (value is Map) {
        final method = value['method']?.toString().toUpperCase();
        if (method == 'PUT') {
          collectParameters(value);
        }

        collectParameters(value['PUT'] ?? value['put']);

        final info = value['info'];
        if (info is Map) {
          collectParameters(info['PUT'] ?? info['put']);
        }

        final methods = value['methods'];
        if (methods is Map) {
          collectParameters(methods['PUT'] ?? methods['put']);
        }

        for (final child in value.values) {
          collectPutSchemas(child);
        }
      } else if (value is Iterable) {
        for (final child in value) {
          collectPutSchemas(child);
        }
      }
    }

    collectPutSchemas(data);

    return GuestConfigEditSchema(
      parameters: parameters,
      isAvailable: foundPutSchema,
    );
  }

  final Set<String> parameters;
  final bool isAvailable;

  bool isEditable(String key) {
    if (!isAvailable) {
      return true;
    }
    return parameters.any((parameter) => _matchesParameter(parameter, key));
  }

  bool _matchesParameter(String parameter, String key) {
    if (parameter == key) {
      return true;
    }

    try {
      if (RegExp('^$parameter\$').hasMatch(key)) {
        return true;
      }
    } on FormatException {
      // Not every schema key is a valid regular expression.
    }

    final wildcardIndex = parameter.indexOf('[n]');
    if (wildcardIndex == -1) {
      return false;
    }

    final prefix = parameter.substring(0, wildcardIndex);
    final suffix = parameter.substring(wildcardIndex + 3);
    if (!key.startsWith(prefix) || !key.endsWith(suffix)) {
      return false;
    }

    final number = key.substring(prefix.length, key.length - suffix.length);
    return number.isNotEmpty && int.tryParse(number) != null;
  }
}
