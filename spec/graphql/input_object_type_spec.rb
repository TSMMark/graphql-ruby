# frozen_string_literal: true
require "spec_helper"

describe GraphQL::InputObjectType do
  let(:input_object) { DairyProductInputType }
  it "has a description" do
    assert(input_object.description)
  end

  it "has input fields" do
    assert(DairyProductInputType.input_fields["fatContent"])
  end

  describe "on a type unused by the schema" do
    it "has input fields" do
      UnreachedInputType = GraphQL::InputObjectType.define do
        name 'UnreachedInputType'
        description 'An input object type not directly used in the schema.'

        input_field :field, types.String
      end
      assert(UnreachedInputType.input_fields['field'])
    end
  end

  describe "input validation" do
    it "Accepts anything that yields key-value pairs to #all?" do
      values_obj = MinimumInputObject.new({"source" => "COW", "fatContent" => 0.4})
      assert DairyProductInputType.valid_input?(values_obj, PermissiveWarden)
    end

    describe "validate_input with non-enumerable input" do
      it "returns a valid result for MinimumInputObject" do
        result = DairyProductInputType.validate_input(MinimumInputObject.new({"source" => "COW", "fatContent" => 0.4}), PermissiveWarden)
        assert(result.valid?)
      end

      it "returns an invalid result for MinimumInvalidInputObject" do
        invalid_input = MinimumInputObject.new({"source" => "KOALA", "fatContent" => 0.4})
        result = DairyProductInputType.validate_input(invalid_input, PermissiveWarden)
        assert(!result.valid?)
      end
    end

    describe "validate_input with null" do
      let(:schema) { GraphQL::Schema.from_definition(%|
        type Query {
          a: Int
        }

        input ExampleInputObject {
          a: String
          b: Int!
        }
      |) }
      let(:input_type) { schema.types['ExampleInputObject'] }

      it "returns an invalid result when value is null for non-null argument" do
        invalid_input = MinimumInputObject.new({"a" => "Test", "b" => nil})
        result = input_type.validate_input(invalid_input, PermissiveWarden)
        assert(!result.valid?)
      end

      it "returns valid result when value is null for nullable argument" do
        invalid_input = MinimumInputObject.new({"a" => nil, "b" => 1})
        result = input_type.validate_input(invalid_input, PermissiveWarden)
        assert(result.valid?)
      end
    end

    describe "validate_input with enumerable input" do
      describe "with good input" do
        let(:input) do
          {
            "source" => "COW",
            "fatContent" => 0.4
          }
        end
        let(:result) { DairyProductInputType.validate_input(input, PermissiveWarden) }

        it "returns a valid result" do
          assert(result.valid?)
        end
      end

      if ActionPack::VERSION::MAJOR > 3
        describe "with a ActionController::Parameters" do
          let(:input) do
            ActionController::Parameters.new(
              "source" => "COW",
              "fatContent" => 0.4,
            )
          end
          let(:result) { DairyProductInputType.validate_input(input, PermissiveWarden) }

          it "returns a valid result" do
            assert(result.valid?)
          end
        end
      end

      describe "with bad enum and float" do
        let(:result) { DairyProductInputType.validate_input({"source" => "KOALA", "fatContent" => "bad_num"}, PermissiveWarden) }

        it "returns an invalid result" do
          assert(!result.valid?)
        end

        it "has problems with correct paths" do
          paths = result.problems.map { |p| p["path"] }
          assert(paths.include?(["source"]))
          assert(paths.include?(["fatContent"]))
        end

        it "has correct problem explanation" do
          expected = DairyAnimalEnum.validate_input("KOALA", PermissiveWarden).problems[0]["explanation"]

          source_problem = result.problems.detect { |p| p["path"] == ["source"] }
          actual = source_problem["explanation"]

          assert_equal(expected, actual)
        end
      end

      describe 'with a string as input' do
        let(:result) { DairyProductInputType.validate_input("just a string", PermissiveWarden) }

        it "returns an invalid result" do
          assert(!result.valid?)
        end

        it "has problem with correct path" do
          paths = result.problems.map { |p| p["path"] }
          assert(paths.include?([]))
        end

        it "has correct problem explanation" do
          assert(result.problems[0]["explanation"].include?("to be a key, value object"))
        end
      end

      describe 'with an array as input' do
        let(:result) { DairyProductInputType.validate_input(["string array"], PermissiveWarden) }

        it "returns an invalid result" do
          assert(!result.valid?)
        end

        it "has problem with correct path" do
          paths = result.problems.map { |p| p["path"] }
          assert(paths.include?([]))
        end

        it "has correct problem explanation" do
          assert(result.problems[0]["explanation"].include?("to be a key, value object"))
        end
      end

      describe 'with a int as input' do
        let(:result) { DairyProductInputType.validate_input(10, PermissiveWarden) }

        it "returns an invalid result" do
          assert(!result.valid?)
        end

        it "has problem with correct path" do
          paths = result.problems.map { |p| p["path"] }
          assert(paths.include?([]))
        end

        it "has correct problem explanation" do
          assert(result.problems[0]["explanation"].include?("to be a key, value object"))
        end
      end

      describe "with extra argument" do
        let(:result) { DairyProductInputType.validate_input({"source" => "COW", "fatContent" => 0.4, "isDelicious" => false}, PermissiveWarden) }

        it "returns an invalid result" do
          assert(!result.valid?)
        end

        it "has problem with correct path" do
          paths = result.problems.map { |p| p["path"] }
          assert_equal(paths, [["isDelicious"]])
        end

        it "has correct problem explanation" do
          assert(result.problems[0]["explanation"].include?("Field is not defined"))
        end
      end

      describe "list with one invalid element" do
        let(:list_type) { GraphQL::ListType.new(of_type: DairyProductInputType) }
        let(:result) do
          list_type.validate_input([
            { "source" => "COW", "fatContent" => 0.4 },
            { "source" => "KOALA", "fatContent" => 0.4 }
          ], PermissiveWarden)
        end

        it "returns an invalid result" do
          assert(!result.valid?)
        end

        it "has one problem" do
          assert_equal(result.problems.length, 1)
        end

        it "has problem with correct path" do
          path = result.problems[0]["path"]
          assert_equal(path, [1, "source"])
        end

        it "has problem with correct explanation" do
          expected = DairyAnimalEnum.validate_input("KOALA", PermissiveWarden).problems[0]["explanation"]
          actual = result.problems[0]["explanation"]
          assert_equal(expected, actual)
        end
      end
    end
  end

  describe "coerce_result" do
    it "omits unspecified arguments" do
      result = input_object.coerce_result(fatContent: 0.3)
      assert_equal ["fatContent"], result.keys
      assert_equal 0.3, result["fatContent"]
    end
  end

  describe "coercion of null inputs" do
    let(:schema) { GraphQL::Schema.from_definition(%|
      type Query {
        a: Int
      }

      input ExampleInputObject {
        a: String
        b: Int!
        c: String = "Default"
      }
    |) }
    let(:input_type) { schema.types['ExampleInputObject'] }

    it "null values are returned in coerced input" do
      input = MinimumInputObject.new({"a" => "Test", "b" => nil,"c" => "Test"})
      result = input_type.coerce_input(input)

      assert_equal 'Test', result['a']

      assert result.key?('b')
      assert_equal nil, result['b']

      assert_equal "Test", result['c']
    end

    it "null values are preserved when argument has a default value" do
      input = MinimumInputObject.new({"a" => "Test", "b" => 1, "c" => nil})
      result = input_type.coerce_input(input)

      assert_equal 'Test', result['a']
      assert_equal 1, result['b']

      assert result.key?('c')
      assert_equal nil, result['c']
    end

    it "omitted arguments are not returned" do
      input = MinimumInputObject.new({"b" => 1, "c" => "Test"})
      result = input_type.coerce_input(input)

      assert !result.key?('a')
      assert_equal 1, result['b']
      assert_equal 'Test', result['c']
    end
  end

  describe "when sent into a query" do
    let(:variables) { {} }
    let(:result) { DummySchema.execute(query_string, variables: variables) }

    describe "list inputs" do
      let(:variables) { {"search" => [MinimumInputObject.new({"source" => "COW", "fatContent" => 0.4})]} }
      let(:query_string) {%|
        query getCheeses($search: [DairyProductInput]!){
            sheep: searchDairy(product: [{source: SHEEP, fatContent: 0.1}]) {
              ... cheeseFields
            }
            cow: searchDairy(product: $search) {
              ... cheeseFields
            }
        }

        fragment cheeseFields on Cheese {
          flavor
        }
      |}

      it "converts items to plain values" do
        sheep_value = result["data"]["sheep"]["flavor"]
        cow_value = result["data"]["cow"]["flavor"]
        assert_equal("Manchego", sheep_value)
        assert_equal("Brie", cow_value)
      end
    end

    describe "scalar inputs" do
      let(:query_string) {%|
        {
          cheese(id: 1.4) {
            flavor
          }
        }
      |}

      it "converts them to the correct type" do
        cheese_name = result["data"]["cheese"]["flavor"]
        assert_equal("Brie", cheese_name)
      end
    end
  end

  describe "#dup" do
    it "shallow-copies internal state" do
      input_object_2 = input_object.dup
      input_object_2.arguments["nonsense"] = GraphQL::Argument.define(name: "int", type: GraphQL::INT_TYPE)
      assert_equal 4, input_object.arguments.size
      assert_equal 5, input_object_2.arguments.size
    end
  end
end
