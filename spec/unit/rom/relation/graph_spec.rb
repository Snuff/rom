require 'spec_helper'

describe ROM::Relation::Graph do
  subject(:graph) { ROM::Relation::Graph.new(users, [tasks.for_users]) }

  include_context 'users and tasks'

  it_behaves_like 'materializable relation' do
    let(:mapper) do
      T(:combine, [[:tasks, name: :name]])
    end

    let(:relation) do
      ROM::Relation::Graph.new(users.by_name('Jane'), [tasks.for_users]) >> mapper
    end
  end

  before do
    setup.relation(:users) do
      def by_name(name)
        restrict(name: name)
      end
    end

    setup.relation(:tasks) do
      def for_users(_users)
        self
      end
    end
  end

  let(:users) { rom.relation(:users) }
  let(:tasks) { rom.relation(:tasks) }

  describe '#method_missing' do
    it 'responds to the root methods' do
      expect(graph).to respond_to(:by_name)
    end

    it 'forwards methods to the root and decorates response' do
      expect(graph.by_name('Jane')).to be_instance_of(ROM::Relation::Graph)
    end

    it 'forwards methods to the root and decorates curried response' do
      expect((users.combine(tasks.for_users)).by_name).to be_instance_of(ROM::Relation::Graph)
    end

    it 'returns original response from the root' do
      expect(graph.mappers).to eql(users.mappers)
    end

    it 'raises method error' do
      expect { graph.not_here }.to raise_error(NoMethodError, /not_here/)
    end
  end

  describe '#call' do
    it 'materializes relations' do
      expect(graph.call).to match_array([
        rom.relations.users,
        [rom.relations.tasks]
      ])
    end
  end

  describe '#to_a' do
    it 'coerces to an array' do
      expect(graph).to match_array([
        users.to_a,
        [tasks.for_users(users).to_a]
      ])
    end

    it 'returns empty arrays when left was empty' do
      graph = ROM::Relation::Graph.new(users.by_name('Not here'), [tasks.for_users])

      expect(graph).to match_array([
        [], [ROM::Relation::Loaded.new(tasks.for_users, [])]
      ])
    end
  end
end
