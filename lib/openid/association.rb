require "openid/kvform"
require "openid/util"

module OpenID

  # An Association holds the shared secret between a relying party and
  # an OpenID provider.
  class Association
    attr_reader :handle, :secret, :issued, :lifetime, :assoc_type

    FIELD_ORDER =
      [:version, :handle, :secret, :issued, :lifetime, :assoc_type,]

    # Load a serialized Association
    def self.deserialize(serialized)
      parsed = Util.kv_to_seq(serialized)
      parsed_fields = parsed.map{|k, v| k.to_sym}
      if parsed_fields != FIELD_ORDER
          raise StandardError, 'Unexpected fields in serialized association'\
          " (Expected #{FIELD_ORDER.inspect}, got #{parsed_fields.inspect})"
      end
      version, handle, secret64, issued_s, lifetime_s, assoc_type =
        parsed.map {|field, value| value}
      if version != '2'
        raise StandardError, "Attempted to deserialize unsupported version "\
                             "(#{parsed[0][1].inspect})"
      end

      self.new(handle,
               Util.from_base64(secret64),
               Time.at(issued_s.to_i),
               lifetime_s.to_i,
               assoc_type)
    end

    # Create an Association with an issued time of now
    def self.from_expires_in(expires_in, handle, secret, assoc_type)
      issued = Time.now
      self.new(handle, secret, issued, expires_in, assoc_type)
    end

    def initialize(handle, secret, issued, lifetime, assoc_type)
      @handle = handle
      @secret = secret
      @issued = issued
      @lifetime = lifetime
      @assoc_type = assoc_type
    end

    # Serialize the association to a form that's consistent across
    # JanRain OpenID libraries.
    def serialize
      data = {
        :version => '2',
        :handle => handle,
        :secret => Util.to_base64(secret),
        :issued => issued.to_i.to_s,
        :lifetime => lifetime.to_i.to_s,
        :assoc_type => assoc_type,
      }

      Util.assert(data.length == FIELD_ORDER.length)

      pairs = FIELD_ORDER.map{|field| [field.to_s, data[field]]}
      return Util.seq_to_kv(pairs, strict=true)
    end

    # The number of seconds until this association expires
    def expires_in(now=nil)
      if now.nil?
        now = Time.now
      elsif now.is_a?(Integer)
        now = Time.at(now)
      end
      (issued + lifetime) - now
    end

    # Generate a signature for a sequence of [key, value] pairs
    def sign(pairs)
      kv = Util.seq_to_kv(pairs)
      case assoc_type
      when 'HMAC-SHA1'
        CryptUtil.hmac_sha1(secret, kv)
      when 'HMAC-SHA256'
        CryptUtil.hmac_sha256(secret, kv)
      else
        raise StandardError, "Association has unknown type: "\
          "#{assoc_type.inspect}"
      end
    end
  end
end