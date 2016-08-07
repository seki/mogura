class Card
  @@ser = 0

  ORDER = [:candy, :gift, :map, :kanban, :break, :red, :yellow, :blue]

  def self.create_from_line(line)
    ary = line.split(' ')
    case ary[0]
    when 'break'
      self.break
    when 'map'
      self.map
    when 'kanban'
      self.kanban
    when 'candy'
      self.candy
    when 'gift'
      self.gift
    else
      self.item(ary[0], ary[1], ary[2].to_i)
    end
  end
  
  def self.break
    self.new([:break], "\u{2668}", 5, :recovery, 2)
  end

  def self.map
    self.new([:map], 'map', 4, :search_candy, 2)
  end

  def self.kanban
    self.new([:kanban], 'kanban', 2, :search_gift, 1)
  end

  def self.candy
    self.new([:candy], "candy", 2, :get, 2)
  end

  def self.gift
    self.new([:gift], "gift", 2, :get, 1)
  end

  def self.item(color, item, cost)
    e_color = case color
              when 'red'
                "\u{1f49c}"
              when 'blue'
                "\u{1f499}"
              when 'yellow'
                "\u{1f49b}"
              end
    e_item = case item
              when 'glasses'
                "\u{1F576}"
              when 'necklace'
                "\u{1f4ff}"
              when 'bag'
                "\u{1f45c}"
              end

    name = "#{e_color}  #{e_item}  #{cost}"
    case cost
    when 1
      self.new([color.intern, item.intern], name, cost, :get, 2)
    when 2
      self.new([color.intern, item.intern], name, cost, :get, 3)
    when 3
      self.new([color.intern, item.intern], name, cost, :get, 5)
    when 4
      self.new([color.intern, item.intern], name, cost, :get, 7, true)
    end
  end

  def initialize(kind, name, cost, action, open, spread=false)
    @kind = kind
    @@ser += 1
    @ser = @@ser
    @name = name
    @cost = cost
    @action = action
    @open = open
    @spread = spread
    @order = [ORDER.index(kind[0]), kind[1], -@cost] 
  end
  attr_reader :ser, :name, :action, :order, :kind, :cost

  def candy?
    @kind[0] == :candy
  end

  def gift?
    @kind[0] == :gift
  end

  def item?
    [:blue, :red, :yellow].include?(@kind[0])
  end

  def to_a
      [@name, "cost: #{@cost}", @action.to_s,
       (@spread ? 'spread' : 'open') +  ": #{@open}"]
  end

  def to_s
    to_a.join("\n ")
  end

  def todo
    [[:cost, @cost],
     [@action, self],
     [:show, @open],
     [(@spread ? :spread_else : :outlet_else), nil]]
  end
end

class Deck
  class EmptyError < RuntimeError; end

  CARDS = <<EOS
break
break
break
break
break
break
yellow glasses 1
yellow necklace 1
yellow bag 1
yellow glasses 4
yellow necklace 4
yellow bag 4
yellow glasses 2
yellow necklace 2
yellow bag 2
yellow glasses 3
yellow necklace 3
yellow bag 3
blue glasses 2
blue necklace 2
blue bag 2
blue glasses 1
blue necklace 1
blue bag 1
blue glasses 4
blue necklace 4
blue bag 4
blue glasses 3
blue necklace 3
blue bag 3
red glasses 2
red necklace 2
red bag 2
red glasses 4
red necklace 4
red bag 4
red glasses 1
red necklace 1
red bag 1
red glasses 3
red necklace 3
red bag 3
candy
candy
candy
candy
candy
candy
candy
candy
gift
gift
gift
gift
map
map
map
map
kanban
kanban
EOS

  @@cards = CARDS.split("\n").map do |line|
    Card.create_from_line(line.chomp)
  end

  def initialize
    @ary = @@cards.sort_by {rand}
    @lost = []
    @trash = []
    @bag = []
    @used = []
    @current = nil
    @code = []
    @hand = nil
    @todo = [[:show, 3], [:outlet_else, nil]]
    show(3)
  end
  attr_reader :ary, :lost, :current, :used, :bag
  attr_reader :hand

  def prompt
    @todo.first
  end

  def outlet
    @trash
  end

  def size
    @ary.size
  end

  def show(n)
    raise EmptyError if @ary.empty?
    @hand = @ary.shift(n).sort_by {|x| x.order}
  ensure
    @todo.shift
  end

  def trash(card)
    @trash << card
  end

  def cost(n)
    return if @ary.size < n
    @lost.push(* @ary.shift(n))
    @todo.shift
  end

  def prize(card)
    if @trash.delete(card)
      @ary << card
    end
  ensure
    @todo.shift
  end

  def outlet_else(card)
    @hand.each do |it|
      trash(it) unless it == card
    end
    @hand = nil
    @current = card
    @todo = card.todo
  end

  def spread_else(card)
    @hand.each do |it|
      @ary << it unless it == card
    end
    @hand = nil
    @current = card
    @todo = card.todo
  end

  def try_combo(card)
    return false unless card.item?
    found = [:bag, :glasses, :necklace].find_all {|x| x != card.kind[1]}.inject([]) do |ary, y|
      it = @bag.find {|z| z.kind == [card.kind[0], y]}
      ary + [it].compact
    end
    return false if found.size != 2
    @bag.delete(found[0])
    @bag.delete(found[1])
    @used << found[0]
    @used << found[1]
    @used << card
  end

  def get(card)
    if try_combo(card)
      @todo[1, 0] = [[:prize, nil]] unless @trash.empty?
      p [:combo, @todo]
    else
      @bag << card
    end
  ensure
    @current = nil
    @todo.shift
  end

  def recovery(card)
    @ary = @ary + @trash
    @trash = []
    @ary = @ary.sort_by {rand}
    @bag << card
  ensure
    @current = nil
    @todo.shift
  end

  def search_candy(card)
    ary = []
    candy = []
    @ary.each do |it|
      if it.candy? && candy.size < 2
        candy << it
      else
        ary << it
      end
    end
    @ary = ary.sort_by {rand}
    @bag = @bag + candy
    @used << card
  ensure
    @current = nil
    @todo.shift
  end

  def search_gift(card)
    ary = []
    gift = []
    @ary.each do |it|
      if it.gift? && gift.size < 1
        gift << it
      else
        ary << it
      end
    end
    @ary = ary.sort_by {rand}
    @bag = @bag + gift
    @used << card
  ensure
    @current = nil
    @todo.shift
  end

  def do_candy_or_gift(found)
    return unless found
    @bag.delete(found)
    @trash << found
    @lost = @lost.sort_by {rand}
    ary = @lost.shift(5)
    @ary = (@ary + ary).sort_by {rand}
  end

  def do_candy
    do_candy_or_gift(@bag.find {|it| it.candy?})
  end

  def do_gift
    do_candy_or_gift(@bag.find {|it| it.gift?})
  end

  def summary
    bin = @bag.inject(Hash.new(0)) {|h, x| h[x.kind] += 1; h}
    result = {
      :candy => bin[[:candy]],
      :gift => bin[[:gift]],
      :break => bin[[:break]]
    }
    colors = [:red, :yellow, :blue]
    items = [:glasses, :necklace, :bag]
    colors.each do |color|
      result[color] = items.map {|item| bin[[color, item]]}.min
    end
    result[:tricolor] = colors.map {|color| result[color]}.min
    result[:score] = result[:candy] + result[:gift] * 2 +
      (result[:red] + result[:yellow] + result[:blue]) * 3 +
      result[:break] + result[:tricolor] * 2
    result
  end
end