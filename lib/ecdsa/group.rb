require_relative 'prime_field'
require_relative 'point'

module ECDSA
  class Group
    # The name of the group.
    # @return (String)
    attr_reader :name

    # The generator point.
    # @return (Point)
    attr_reader :generator

    # The order of the group.  This is the smallest positive
    # integer `i` such that the generator point multiplied by `i` is infinity.
    # This is also the number of different points that are on the curve.
    # @return (Order)
    attr_reader :order

    # The a parameter in the curve equation (*y^2 = x^3 + ax + b*).
    # @option opts :a (Integer)
    attr_reader :param_a

    # The b parameter in the curve equation.
    # @return (Integer)
    attr_reader :param_b

    # The field that coordinates on the curve belong to.
    # @return (PrimeField)
    attr_reader :field

    # These parameters are defined in http://www.secg.org/collateral/sec2_final.pdf
    #
    # @param opts (Hash)
    # @option opts :p (Integer) A prime number that defines the field used.  The field will be *F<sub>p</sub>*.
    # @option opts :a (Integer) The a parameter in the curve equation (*y^2 = x^3 + ax + b*).
    # @option opts :b (Integer) The b parameter in the curve equation.
    # @option opts :g (Array(Integer)) The coordinates of the generator point, with x first.
    # @option opts :n (Integer) The order of g.  This is the smallest positive
    #   integer `i` such that the generator point multiplied by `i` is infinity.
    #   This is also the number of different points that are on the curve.
    # @option opts :h (Integer) The cofactor (optional).
    def initialize(opts)
      @opts = opts

      @name = opts.fetch(:name) { '%#x' % object_id }
      @field = PrimeField.new(opts[:p])
      @param_a = opts[:a]
      @param_b = opts[:b]
      @generator = new_point(@opts[:g])
      @order = opts[:n]
      @cofactor = opts[:h]

      @param_a.is_a?(Integer) or raise ArgumentError, 'Invalid a.'
      @param_b.is_a?(Integer) or raise ArgumentError, 'Invalid b.'

      @param_a = field.mod @param_a
      @param_b = field.mod @param_b
    end

    # Creates a new point.
    # The argument can either be an array of integers representing the
    # coordinates, with x first, or it can be `:infinity`.
    def new_point(p)
      case p
      when :infinity
        infinity
      when Array
        x, y = p
        Point.new(self, x, y)
      when Integer
        generator.multiply_by_scalar(p)
      else
        raise ArgumentError, "Invalid point specifier #{p.inspect}."
      end
    end

    # Returns the infinity point.
    #
    # @return (Point)
    def infinity
      @infinity ||= Point.new(self, :infinity)
    end

    # The number of bits that it takes to represent a member of the field.
    # Log base 2 of the prime p, rounded up.
    #
    # @return (Integer)
    def bit_length
      @bit_length ||= ECDSA.bit_length(field.prime)
    end

    # The number of bytes that it takes to represent a member of the field.
    # Log base 256 of the prime p, rounded up.
    #
    # @return (Integer)
    def byte_length
      @byte_length ||= ECDSA.byte_length(field.prime)
    end

    # Returns true if the point is a solution to the curve's defining equation
    # or if it is the infinity point.
    def include?(point)
      return false if point.group != self
      point.infinity? or point_satisfies_equation?(point)
    end

    # Returns true if the point is not infinity, it is a solution to the curve's
    # defining equation, and it is a multiple of G.  This process is defined in
    # SEC1 2.0, Section 3.2.2.1: Elliptic Curve Public Key Partial Validation Primitive
    def valid_public_key?(point)
      return false if point.group != self
      return false if point.infinity?
      return false if !point_satisfies_equation?(point)
      point.multiply_by_scalar(order).infinity?
    end

    # Returns true if the point is not infinity and it is a solution to
    # the curve's defining equation.  This is defined in
    # SEC1 2.0, Section 3.2.3.1: Elliptic Curve Public Key Partial Validation Primitive
    def partially_valid_public_key?(point)
      return false if point.group != self
      return false if point.infinity?
      point_satisfies_equation?(point)
    end

    # Given the x coordinate of a point, finds all possible corresponding y coordinates.
    #
    # @return (Array)
    def solve_for_y(x)
      field.square_roots equation_right_hand_side x
    end

    # @return (String)
    def inspect
      "#<#{self.class}:#{name}>"
    end

    # @return (String)
    def to_s
      inspect
    end

    private

    def point_satisfies_equation?(point)
      field.square(point.y) == equation_right_hand_side(point.x)
    end

    def equation_right_hand_side(x)
      field.mod(x * x * x + param_a * x + param_b)
    end

    NAMES = %w(
      Nistp192
      Nistp224
      Nistp256
      Nistp384
      Nistp521
      Secp112r1
      Secp112r2
      Secp128r1
      Secp128r2
      Secp160k1
      Secp160r1
      Secp160r2
      Secp192k1
      Secp192r1
      Secp224k1
      Secp224r1
      Secp256k1
      Secp256r1
      Secp384r1
      Secp521r1
    )

    NAMES.each do |name|
      autoload name, 'ecdsa/group/' + name.downcase
    end

    # Group#infinity_point was deprecated in favor of #infinity.
    # This alias is for backwards compatibility with versions 0.1.4 and before.
    alias_method :infinity_point, :infinity
  end
end
