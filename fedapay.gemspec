# -*- encoding: utf-8 -*-
# stub: fedapay 0.1.16 ruby lib

Gem::Specification.new do |s|
  s.name = "fedapay".freeze
  s.version = "0.1.16"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Maelle AHOUMENOU".freeze, "Boris Koumondji".freeze, "Eric AKPLA".freeze]
  s.bindir = "exe".freeze
  s.date = "2022-04-27"
  s.description = "FedaPay is the easiest way to accept mobile money payments online.".freeze
  s.email = ["senma94@gmail.com".freeze, "kplaricos@gmail.com".freeze]
  s.files = [".editorconfig".freeze, ".gitignore".freeze, ".travis.yml".freeze, "CODE_OF_CONDUCT.md".freeze, "Gemfile".freeze, "LICENSE.txt".freeze, "README.md".freeze, "Rakefile".freeze, "bin/console".freeze, "bin/setup".freeze, "fedapay.gemspec".freeze, "lib/data/ca-certificates.crt".freeze, "lib/fedapay.rb".freeze, "lib/fedapay/account.rb".freeze, "lib/fedapay/api_key.rb".freeze, "lib/fedapay/api_operations/create.rb".freeze, "lib/fedapay/api_operations/delete.rb".freeze, "lib/fedapay/api_operations/list.rb".freeze, "lib/fedapay/api_operations/request.rb".freeze, "lib/fedapay/api_operations/save.rb".freeze, "lib/fedapay/api_resource.rb".freeze, "lib/fedapay/currency.rb".freeze, "lib/fedapay/customer.rb".freeze, "lib/fedapay/errors.rb".freeze, "lib/fedapay/event.rb".freeze, "lib/fedapay/fedapay_client.rb".freeze, "lib/fedapay/fedapay_object.rb".freeze, "lib/fedapay/fedapay_response.rb".freeze, "lib/fedapay/list_object.rb".freeze, "lib/fedapay/log.rb".freeze, "lib/fedapay/page.rb".freeze, "lib/fedapay/payout.rb".freeze, "lib/fedapay/transaction.rb".freeze, "lib/fedapay/util.rb".freeze, "lib/fedapay/version.rb".freeze, "lib/fedapay/webhook.rb".freeze, "lib/fedapay/webhook_signature.rb".freeze]
  s.homepage = "https://github.com/fedapay/fedapay-ruby".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.1.6".freeze
  s.summary = "Ruby library for FedaPay https://fedapay.com.".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<faraday>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<activesupport>.freeze, [">= 0"])
  else
    s.add_dependency(%q<faraday>.freeze, [">= 0"])
    s.add_dependency(%q<activesupport>.freeze, [">= 0"])
  end
end
