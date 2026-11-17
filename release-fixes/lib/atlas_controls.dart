import 'package:flutter/material.dart';

const _controlInk = Color(0xFF173F3B);
const _controlText = Color(0xFF344B47);
const _controlLine = Color(0xFFDCE5DF);

/// Shared selection field for every active tertiary screen and dialog.
class AtlasDropdown<T> extends StatefulWidget {
  final T? initialValue;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final bool isExpanded;
  final FormFieldValidator<T>? validator;
  final Widget? hint;
  const AtlasDropdown({
    super.key,
    this.initialValue,
    required this.items,
    required this.onChanged,
    this.decoration = const InputDecoration(),
    this.isExpanded = true,
    this.validator,
    this.hint,
  });
  @override
  State<AtlasDropdown<T>> createState() => _AtlasDropdownState<T>();
}

class _AtlasDropdownState<T> extends State<AtlasDropdown<T>> {
  T? selected;
  @override
  void initState() {
    super.initState();
    selected = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant AtlasDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      selected = widget.initialValue;
    }
  }

  Widget label(Widget child, {required bool menu}) {
    if (child is! Text || child.data == null) return child;
    return Text(
      child.data!,
      style: child.style,
      maxLines: menu ? null : 1,
      overflow: menu ? TextOverflow.visible : TextOverflow.ellipsis,
      softWrap: menu,
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.items;
    final enabled =
        widget.onChanged != null && options != null && options.isNotEmpty;
    return DropdownButtonFormField<T>(
      initialValue: selected,
      hint: widget.hint,
      isExpanded: widget.isExpanded,
      validator: widget.validator,
      isDense: true,
      itemHeight: null,
      enableFeedback: true,
      menuMaxHeight: MediaQuery.sizeOf(context).height < 700 ? 300 : 420,
      dropdownColor: Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      style: const TextStyle(
        fontFamily: 'SkoolSans',
        fontSize: 15,
        height: 1.45,
        color: _controlInk,
      ),
      icon: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFEDF3EF) : const Color(0xFFF1F1EF),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 22,
          color: enabled ? _controlInk : Colors.grey,
        ),
      ),
      decoration: widget.decoration.copyWith(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        labelStyle: const TextStyle(
          color: _controlText,
          fontSize: 14,
          height: 1.4,
        ),
        floatingLabelStyle: const TextStyle(
          color: _controlInk,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _controlLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _controlInk, width: 1.8),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _controlLine),
        ),
      ),
      selectedItemBuilder: options == null
          ? null
          : (_) => [
              for (final option in options)
                Align(
                  alignment: Alignment.centerLeft,
                  child: label(option.child, menu: false),
                ),
            ],
      items: options == null
          ? null
          : [
              for (final option in options)
                DropdownMenuItem<T>(
                  value: option.value,
                  enabled: option.enabled,
                  onTap: option.onTap,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: option.value == selected
                          ? const Color(0xFFEDF5F0)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: label(option.child, menu: true)),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 20,
                          child: option.value == selected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: _controlInk,
                                  size: 19,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
      onChanged: !enabled
          ? null
          : (value) {
              setState(() => selected = value);
              widget.onChanged!(value);
            },
    );
  }
}

/// Framed, accessible disclosure rather than a heading that looks like plain text.
class AtlasDisclosure extends StatefulWidget {
  final Widget title;
  final Widget? subtitle, leading;
  final List<Widget> children;
  final EdgeInsetsGeometry? tilePadding, childrenPadding;
  final CrossAxisAlignment? expandedCrossAxisAlignment;
  final ShapeBorder? shape, collapsedShape;
  final Color? iconColor, collapsedIconColor;
  final bool initiallyExpanded;
  const AtlasDisclosure({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.children,
    this.tilePadding,
    this.childrenPadding,
    this.expandedCrossAxisAlignment,
    this.shape,
    this.collapsedShape,
    this.iconColor,
    this.collapsedIconColor,
    this.initiallyExpanded = false,
  });
  @override
  State<AtlasDisclosure> createState() => _AtlasDisclosureState();
}

class _AtlasDisclosureState extends State<AtlasDisclosure> {
  late bool expanded = widget.initiallyExpanded;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: expanded ? const Color(0xFFFAFCFA) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: expanded ? const Color(0xFFA8C4B6) : _controlLine,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            initiallyExpanded: widget.initiallyExpanded,
            onExpansionChanged: (value) => setState(() => expanded = value),
            tilePadding:
                widget.tilePadding ??
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            childrenPadding:
                widget.childrenPadding ??
                const EdgeInsets.fromLTRB(16, 4, 16, 18),
            expandedCrossAxisAlignment:
                widget.expandedCrossAxisAlignment ?? CrossAxisAlignment.start,
            shape: widget.shape ?? const Border(),
            collapsedShape: widget.collapsedShape ?? const Border(),
            iconColor: widget.iconColor ?? _controlInk,
            collapsedIconColor: widget.collapsedIconColor ?? _controlInk,
            leading: constraints.maxWidth < 360
                ? null
                : Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF3EF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconTheme(
                      data: const IconThemeData(size: 19, color: _controlInk),
                      child: widget.leading ?? const Icon(Icons.tune_rounded),
                    ),
                  ),
            trailing: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFEDF3EF),
                borderRadius: BorderRadius.circular(9),
              ),
              child: AnimatedRotation(
                turns: expanded ? .5 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: _controlInk,
                ),
              ),
            ),
            title: DefaultTextStyle.merge(
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: _controlInk,
              ),
              child: widget.title,
            ),
            subtitle: widget.subtitle == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: DefaultTextStyle.merge(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: _controlText,
                      ),
                      child: widget.subtitle!,
                    ),
                  ),
            children: widget.children,
          ),
        ),
      ),
    ),
  );
}

/// Equal-width mobile action pairs with readable, wrapping labels.
class AtlasActionRow extends StatelessWidget {
  final List<Widget> children;
  const AtlasActionRow({super.key, required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    final compact = box.maxWidth < 560;
    final columns = compact ? 2 : (children.length > 4 ? 4 : children.length);
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: compact ? 8 : 14, vertical: 12)),
      textStyle: WidgetStatePropertyAll(TextStyle(fontSize: compact ? 12 : 14, fontWeight: FontWeight.w600)),
      iconSize: const WidgetStatePropertyAll(16),
      alignment: Alignment.center,
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
    return FilledButtonTheme(
      data: FilledButtonThemeData(style: style),
      child: OutlinedButtonTheme(
        data: OutlinedButtonThemeData(style: style),
        child: TextButtonTheme(
          data: TextButtonThemeData(style: style),
          child: DefaultTextStyle.merge(
            textAlign: TextAlign.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (var start = 0; start < children.length; start += columns) ...[
                if (start > 0) const SizedBox(height: 10),
                IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (var index = start; index < start + columns && index < children.length; index++) ...[
                    if (index > start) const SizedBox(width: 10),
                    Expanded(child: children[index]),
                  ],
                ])),
              ],
            ]),
          ),
        ),
      ),
    );
  });
}
