require 'rom/relation/loaded'
require 'rom/relation/composite'
require 'rom/relation/materializable'
require 'rom/pipeline'

module ROM
  class Relation
    # Load a relation with its associations
    #
    # @example
    #   ROM.setup(:memory)
    #
    #   class Users < ROM::Relation[:memory]
    #   end
    #
    #   class Tasks < ROM::Relation[:memory]
    #     def for_users(users)
    #       restrict(user: users.map { |user| user[:name] })
    #     end
    #   end
    #
    #   rom = ROM.finalize.env
    #
    #   rom.relations[:users] << { name: 'Jane' }
    #   rom.relations[:tasks] << { user: 'Jane', title: 'Do something' }
    #
    #   rom.relation(:users).combine(rom.relation(:tasks).for_users)
    #
    # @api public
    class Graph
      include Materializable
      include Pipeline
      include Pipeline::Proxy

      # Root aka parent relation
      #
      # @return [Relation::Lazy]
      #
      # @api private
      attr_reader :root

      # Child relation nodes
      #
      # @return [Array<Relation::Lazy>]
      #
      # @api private
      attr_reader :nodes

      alias_method :left, :root
      alias_method :right, :nodes

      # @api private
      def self.build(root, nodes)
        if nodes.any? { |node| node.instance_of?(Composite) }
          raise UnsupportedRelationError,
            "Combining with composite relations is not supported"
        else
          new(root, nodes)
        end
      end

      # @api private
      def initialize(root, nodes)
        @root = root
        @nodes = nodes
      end

      # Combine this graph with more nodes
      #
      # @param [Array<Relation::Lazy>]
      #
      # @return [Graph]
      #
      # @api public
      def combine(*others)
        self.class.new(root, nodes + others)
      end

      # Materialize this relation graph
      #
      # @return [Loaded]
      #
      # @api public
      def call(*args)
        left = root.call(*args)

        right =
          if left.count > 0
            nodes.map { |node| node.call(left) }
          else
            nodes.map { |node| Loaded.new(node, []) }
          end

        Loaded.new(self, [left, right])
      end

      private

      # @api private
      def decorate?(other)
        super || other.is_a?(Curried)
      end
    end
  end
end
