require 'd-mark'

class NanocWsCommonTranslator < DMark::Translator
  def to_id(string)
    string.downcase.gsub(/\W+/, '-').gsub(/^-|-$/, '')
  end

  def text_content_of(node)
    case node
    when String
      node
    when DMark::ElementNode
      node.children.map { |c| text_content_of(c) }.join
    else
      raise "Unknown node type: #{node.class}"
    end
  end

  def nodes_for_item(item)
    if item.identifier.ext == 'dmark'
      begin
        DMark::Parser.new(item.raw_content).parse
      rescue => e
        handle_error(e, item.raw_content)
      end
    else
      nil
    end
  end

  def has_content?(node)
    if node.nil? || node.children.empty?
      false
    elsif node.children.any? { |n| !n.is_a?(String) }
      true
    elsif node.children.all? { |s| s.empty? }
      false
    else
      true
    end
  end

  def node_with_id(id, nodes:)
    # FIXME: ugly implementation

    candidate = nodes.find { |n| n.is_a?(DMark::ElementNode) && n.attributes['id'] == id }
    return candidate if candidate

    nodes.each do |node|
      case node
      when String
      when DMark::ElementNode
        candidate = node_with_id(id, nodes: node.children)
        return candidate if candidate
      end
    end

    nil
  end

  def handle_ref(node, context)
    if node.attributes['url']
      url = node.attributes['url']
      return handle_ref_with_url(node, context, url)
    end

    if node.attributes['item'].nil? && node.attributes['frag'].nil?
      raise "Cannot create ref: no `url`, `item` or `frag` given"
    end

    item_ref = node.attributes['item']
    frag = node.attributes['frag']

    target_item = item_ref ? context[:items][item_ref] : context[:item]
    raise "%ref error: canot find item for #{item_ref.inspect}" if target_item.nil?

    target_nodes = context[:item] == target_item ? context[:nodes] : nodes_for_item(target_item)
    target_node = (target_nodes && frag) ? node_with_id(frag, nodes: target_nodes) : nil

    if has_content?(node)
      handle_ref_with_content(node, context, target_item, frag)
    else
      if node.attributes['bare']
        handle_ref_bare(node, context, target_item, frag, target_node)
      else
        out = []

        if frag
          out << handle_ref_insert_section_ref(node, context, target_item, frag, target_node)
        end

        if frag && target_item != context[:item]
          out << handle_ref_insert_inside_ref(node, context, target_item, frag, target_node)
        end

        if target_item != context[:item]
          out << handle_ref_insert_chapter_ref(node, context, target_item, frag)
        end

        out << handle_ref_insert_end(node, context, target_item, frag, target_node)

        out
      end
    end
  end

  def handle_ref_with_url(node, context, url)
    raise NotImplementedError
  end

  def handle_ref_with_content(node, context, target_item, frag)
    raise NotImplementedError
  end

  def handle_ref_bare(node, context, target_item, frag, target_node)
    raise NotImplementedError
  end

  def handle_ref_insert_section_ref(node, context, target_item, frag, target_node)
    raise NotImplementedError
  end

  def handle_ref_insert_inside_ref(node, context, target_item, frag, target_node)
    raise NotImplementedError
  end

  def handle_ref_insert_chapter_ref(node, context, target_item, frag)
    raise NotImplementedError
  end

  def handle_ref_insert_end(node, context, target_item, frag, target_node)
    raise NotImplementedError
  end
end
