import 'package:catex/src/lookup/context.dart';
import 'package:catex/src/lookup/exception.dart';
import 'package:catex/src/lookup/fonts.dart';
import 'package:catex/src/lookup/modes.dart';
import 'package:catex/src/lookup/styles.dart';
import 'package:catex/src/parsing/parsing.dart';
import 'package:catex/src/rendering/rendering.dart';
import 'package:flutter/widgets.dart';

/// The context that will be passed to the root node in [CaTeX].
///
/// This *does **not** mean* that everything will be rendered using this context.
/// Symbols use different fonts by default. Additionally, there are font functions
/// that modify the font style, color functions that modify the color, and other functions
/// that will need to size their children smaller, e.g. to display a fraction.
/// In general, the context can be modified by any node for its subtree.
final defaultCaTeXContext = CaTeXContext(
  style: CaTeXStyle.d,
  color: const Color(0xffffffff),
  textSize: 32 * 1.21,
  fontFamily: CaTeXFont.main.family,
  // The weight and style are initialized as null in
  // order to be able to override e.g. the italic letter
  // behavior using \rm.
);

/// The mode at the root of the tree.
///
/// This can be modified by any node, e.g.
/// a `\text` function will put its subtree into text mode
/// and a `$` will switch to math mode.
/// It simply means that CaTeX will start out in this mode.
const startParsingMode = CaTeXMode.math;

class CaTeX extends StatefulWidget {
  const CaTeX(this.input, {Key key})
      : assert(input != null),
        super(key: key);

  final String input;

  @override
  State createState() => _CaTeXState();
}

class _CaTeXState extends State<CaTeX> {
  Widget _rootNode;
  CaTeXException _exception;

  void _parse() {
    _exception = null;
    try {
      _rootNode = Parser(widget.input, mode: startParsingMode).parse().createWidget(defaultCaTeXContext);
    } on CaTeXException catch (e) {
      _exception = e;
    }
  }

  @override
  void initState() {
    super.initState();

    _parse();
  }

  @override
  void didUpdateWidget(CaTeX oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.input != widget.input) setState(_parse);
  }

  @override
  Widget build(BuildContext context) {
    if (_exception != null) throw FlutterError(_exception.message);

    // Rendering a full tree can be expensive and the tree never changes.
    // Because of this, we want to insert a repaint boundary between the
    // CaTeX output and the rest of the widget tree.
    return TreeWidget(_rootNode);
  }
}

class TreeWidget extends SingleChildRenderObjectWidget {
  TreeWidget(NodeWidget child)
      : assert(child != null),
        _context = child.context,
        super(child: child);

  final CaTeXContext _context;

  @override
  RenderTree createRenderObject(BuildContext context) => RenderTree(_context);

  @override
  void updateRenderObject(BuildContext context, RenderTree renderObject) {
    renderObject.context = _context;
  }
}

/// Widget that handles creation of [RenderNode]s for all [ParsingNode]s.
class NodeWidget<R extends RenderNode> extends MultiChildRenderObjectWidget {
  /// Creates a widget for [ParsingNode]s that handles creation of the [RenderNode]
  /// subclass of the node.
  ///
  /// Pass [ParsingNode.createRenderNode] to [createRenderNode] and the unmodified
  /// [CaTeXContext] that is given as a parameter to [ParsingNode.configureWidget] to [context].
  /// The context for the render node should be modified in [Parsing.createRenderNode] if needed.
  ///
  /// You do not need to pass anything to [children] (it will be assigned an empty list in that case).
  /// You will want to pass the number of children that your node wants to render, which are
  /// obtained from the [ParsingNode.createWidget] methods of the [ChildrenNode.children].
  /// Logically, you will not specify children if this is constructed from a [LeafNode].
  NodeWidget(this.context, this.createRenderNode, {List<NodeWidget> children})
      : assert(context != null),
        super(
          children: children ?? [],
          // If the widget changes, the render object should also change.
          // Widgets are only updated when a different input is parsed
          // and it should be good enough to completely rebuild the tree at that point.
          // Hence, afaic this is fine.
          key: UniqueKey(),
        );

  final CaTeXContext context;

  final R Function(CaTeXContext context) createRenderNode;

  @override
  R createRenderObject(BuildContext context) => createRenderNode(this.context);
}
