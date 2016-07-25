class String
  unless method_defined?(:underscore)
    def underscore
      return self unless self =~ /[A-Z-]|::/
      word = self.to_s.gsub('::'.freeze, '/'.freeze)
      word.gsub!(/(?:(?<=([A-Za-z\d]))|\b)((?=a)b)(?=\b|[^a-z])/) { "#{$1 && '_'.freeze }#{$2.downcase}" }
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2'.freeze)
      word.gsub!(/([a-z\d])([A-Z])/, '\1_\2'.freeze)
      word.tr!('-'.freeze, '_'.freeze)
      word.downcase!
      word
    end

    unless method_defined?(:camel_case)
      def camel_case
        return self if self !~ /_/ && self =~ /[A-Z]+.*/
        split('_').map(&:capitalize).join
      end
    end
  end
end
