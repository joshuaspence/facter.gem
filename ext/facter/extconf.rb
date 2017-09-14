require 'mini_portile2'
require 'mkmf'

ROOT = File.expand_path('../..', __dir__)

class MiniPortileCMake
  def configure_defaults
    if MiniPortile.windows?
      ['-GUnix Makefiles']
    else
      []
    end
  end

  def make_cmd
    'make'
  end
end

def process_recipe(name, version, cmake)
  recipe_class = cmake ? MiniPortileCMake : MiniPortile

  recipe_class.new(name, version).tap do |recipe|
    recipe.target = File.join(ROOT, 'ports')
    recipe.patch_files = Dir[File.expand_path("./patches/#{recipe.name}/*.patch", ROOT)].sort
    recipe.host = RbConfig::CONFIG['host_alias'].empty? ? RbConfig::CONFIG['host'] : RbConfig::CONFIG['host_alias']

    yield recipe

    if cmake
      recipe.configure_options += [
        '-DCMAKE_VERBOSE_MAKEFILE=ON',
      ]
    end

    unless File.exist?("#{recipe.target}/#{recipe.host}/#{recipe.name}/#{recipe.version}")
      recipe.cook
    end

    recipe.activate
  end
end

boost_recipe = process_recipe('boost', '1.65.1', false) do |recipe|
  recipe.files = [{
    url: "https://dl.bintray.com/boostorg/release/#{recipe.version}/source/#{recipe.name}_#{recipe.version.tr('.', '_')}.tar.gz",
    sha256sum: 'a13de2c8fbad635e6ba9c8f8714a0e6b4264b60a29b964b940a22554705b6b60',
  }]

  recipe.configure_options += [
    'cxxflags=-fPIC',
    'link=static',
  ]

  class << recipe
    def configure
      execute('configure', %w(./bootstrap.sh --with-icu))
    end

    def compile
      execute('compile', %w(./b2) + computed_options)
    end

    def install
      execute('install', %w(./b2 install) + computed_options)
    end
  end
end

yaml_recipe = process_recipe('yaml-cpp', '0.5.3', true) do |recipe|
  recipe.files = [{
    url: "https://github.com/jbeder/#{recipe.name}/archive/#{recipe.name}-#{recipe.version}.tar.gz",
    sha256sum: 'decc5beabb86e8ed9ebeb04358d5363a5c4f72d458b2c788cb2f3ac9c19467b2',
  }]

  recipe.configure_options += [
    '-DCMAKE_POSITION_INDEPENDENT_CODE=ON',
    '-DYAML_CPP_BUILD_CONTRIB=OFF',
    '-DYAML_CPP_BUILD_TOOLS=OFF',
  ]
end

leatherman_recipe = process_recipe('leatherman', '1.2.1', true) do |recipe|
  recipe.files = [{
    url: "https://github.com/puppetlabs/#{recipe.name}/archive/#{recipe.version}.tar.gz",
    sha256sum: '747a12948167634d2c3db8c7be741ceb1eb486f54ed6b5b96fecfd68827e4efb',
  }]

  recipe.configure_options += [
    '-DCURL_STATIC=ON',
    "-DBOOST_ROOT=#{boost_recipe.path}",
    '-DBOOST_STATIC=ON',
    '-DLEATHERMAN_DEFAULT_ENABLE=OFF',
    '-DLEATHERMAN_ENABLE_TESTING=OFF',
    '-DLEATHERMAN_GETTEXT=OFF',
    '-DLEATHERMAN_INSTALL=ON',
    '-DLEATHERMAN_USE_CATCH=ON',
    '-DLEATHERMAN_USE_CURL=ON',
    '-DLEATHERMAN_USE_DYNAMIC_LIBRARY=ON',
    '-DLEATHERMAN_USE_EXECUTION=ON',
    '-DLEATHERMAN_USE_FILE_UTIL=ON',
    '-DLEATHERMAN_USE_LOCALE=ON',
    '-DLEATHERMAN_USE_LOCALES=OFF',
    '-DLEATHERMAN_USE_LOGGING=ON',
    '-DLEATHERMAN_USE_NOWIDE=ON',
    '-DLEATHERMAN_USE_RAPIDJSON=ON',
    '-DLEATHERMAN_USE_RUBY=ON',
    '-DLEATHERMAN_USE_UTIL=ON',
  ]
end

hocon_recipe = process_recipe('hocon', '0.1.5', true) do |recipe|
  recipe.files = [{
    url: "https://github.com/puppetlabs/cpp-#{recipe.name}/archive/#{recipe.version}.tar.gz",
    sha256sum: '4b9d13edf455fd00aedf5a5c151b637f933e796be896f7dc59c9e8255aec99ab',
  }]

  recipe.configure_options += [
    "-DBOOST_ROOT=#{boost_recipe.path}",
    '-DBOOST_STATIC=ON',
    '-DCURL_STATIC=ON',
    "-DLeatherman_DIR=#{leatherman_recipe.path}/lib/cmake/leatherman",
    '-DLEATHERMAN_GETTEXT=OFF',
    '-DLEATHERMAN_USE_LOCALES=OFF',

    # https://gcc.gnu.org/ml/gcc-patches/2015-09/msg00621.html
    '-DCMAKE_CXX_FLAGS=-Wno-address -Wno-nonnull-compare',
  ]
end

facter_recipe = process_recipe('facter', '3.8.0', true) do |recipe|
  recipe.files = [{
    url: "https://github.com/puppetlabs/#{recipe.name}/archive/#{recipe.version}.tar.gz",
    sha256sum: '1a481a50a621e55fdf2b1b2da089315209ec40b255687ad66cbe8bf32cce5ab9',
  }]

  recipe.configure_options += [
    "-DBoost_INCLUDE_DIR=#{boost_recipe.path}/include",
    '-DCURL_STATIC=ON',
    "-DCPPHOCON_INCLUDE_DIR=#{hocon_recipe.path}/include",
    "-DCPPHOCON_LIBRARY=#{hocon_recipe.path}/lib/libcpp-hocon.a",
    "-DLeatherman_DIR=#{leatherman_recipe.path}/lib/cmake/leatherman",
    '-DLEATHERMAN_GETTEXT=OFF',
    '-DLEATHERMAN_USE_LOCALES=OFF',
    "-DYAMLCPP_INCLUDE_DIR=#{yaml_recipe.path}/include",
    "-DYAMLCPP_LIBRARY=#{yaml_recipe.path}/lib/libyaml-cpp.a",
    '-DYAMLCPP_STATIC=ON',

    '-DCMAKE_SHARED_LINKER_FLAGS=-static-libgcc -static-libstdc++',

    # Don't use OpenSSL
    #'-DWITHOUT_BLKID=TRUE',
    '-DWITHOUT_OPENSSL=ON',
  ]
end

create_makefile('libfacter', facter_recipe.path)

new_makefile = StringIO.new
File.open('Makefile', 'r') do |makefile|
  makefile.each_line do |line|
    case line
    when /^TARGET =/
      line = "TARGET = libfacter\n"
    when /^TARGET_NAME =/
      line = "TARGET_NAME = libfacter\n"
    when /^DLLIB =/
      line = "DLLIB = $(TARGET).so\n"
    when /^all:/
      line = "all: $(DLLIB)\n"
    end

    new_makefile.write(line)
  end
end

new_makefile.write(<<~EOS.tr('    ', "\t"))
install-so: $(DLLIB)
    $(INSTALL_PROG) $(DLLIB) $(RUBYARCHDIR)
clean-static::
  -$(Q)$(RM) $(STATIC_LIB)

$(DLLIB): Makefile
    $(ECHO) copying $(DLLIB)
    -$(Q)$(RM) $(@)
    $(Q) $(COPY) #{facter_recipe.path}/lib/libfacter.so $(@)

#pre-install-rb-default: $(TIMESTAMP_DIR)/.RUBYLIBDIR.time
#install-rb-default: $(RUBYLIBDIR)/facter.rb
#$(RUBYLIBDIR)/facter.rb: #{facter_recipe.path}/lib/facter.rb $(TIMESTAMP_DIR)/.RUBYLIBDIR.time
#    $(Q) $(INSTALL_DATA) $(<) $(@D)
#pre-install-rb-default:
#    $(ECHO) installing default Facter libraries
#$(TIMESTAMP_DIR)/.RUBYARCHDIR.time:
#    $(Q) $(MAKEDIRS) $(@D) $(RUBYARCHDIR)
#    $(Q) $(TOUCH) $@
#$(TIMESTAMP_DIR)/.RUBYLIBDIR.time:
#    $(Q) $(MAKEDIRS) $(@D) $(RUBYLIBDIR)
#    $(Q) $(TOUCH) $@

EOS

File.open('Makefile', 'w') do |makefile|
  new_makefile.rewind
  makefile.write(new_makefile.read)
end
