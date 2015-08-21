FROM heroku/cedar:14
MAINTAINER Kosuke Arisawa <arisawa@gmail.com>

## by root
RUN useradd -d /app -m app
RUN mkdir -p /app/user/.ssh
ADD id_rsa /app/.ssh/id_rsa
RUN chmod 700 /app/.ssh/id_rsa
RUN echo "Host github.com\n\tStrictHostKeyChecking no\n" >> /app/.ssh/config
RUN chown -R app:app /app
COPY ./init.sh /usr/bin/init.sh
RUN chmod +x /usr/bin/init.sh

## by app user
USER app
WORKDIR /app/user
ENV HOME /app/user
ENV GEM_PATH /app/local/ruby/bundle/ruby/2.2.0
ENV GEM_HOME /app/local/ruby/bundle/ruby/2.2.0
ENV BUNDLE_APP_CONFIG /app/local/ruby/.bundle
RUN mkdir -p /app/local/ruby/bundle/ruby/2.2.0

# Install Ruby
RUN mkdir -p /app/local/ruby/ruby-2.2.3
RUN curl -s --retry 3 -L https://heroku-buildpack-ruby.s3.amazonaws.com/cedar-14/ruby-2.2.3.tgz | tar xz -C /app/local/ruby/ruby-2.2.3
ENV PATH /app/local/ruby/ruby-2.2.3/bin:$PATH

# Install Node
RUN curl -s --retry 3 -L http://s3pository.heroku.com/node/v0.12.7/node-v0.12.7-linux-x64.tar.gz | tar xz -C /app/local/ruby/
RUN mv /app/local/ruby/node-v0.12.7-linux-x64 /app/local/ruby/node-0.12.7
ENV PATH /app/local/ruby/node-0.12.7/bin:$PATH

# Install Bundler
RUN gem install bundler -v 1.9.10 --no-ri --no-rdoc
ENV PATH /app/user/bin:/app/local/ruby/bundle/ruby/2.2.0/bin:$PATH

# Run bundler to cache dependencies
ONBUILD COPY ["Gemfile", "Gemfile.lock", "/app/user/"]
ONBUILD RUN bundle install --path /app/local/ruby/bundle -j4
ONBUILD ADD . /app/user

# How to conditionally `rake assets:precompile`?
ONBUILD ENV RAILS_ENV production
ONBUILD ENV SECRET_KEY_BASE $(openssl rand -base64 32)
# ONBUILD RUN bundle exec rake assets:precompile        # Define on the child dockerfile

# export env vars during run time
RUN mkdir -p /app/.profile.d/
RUN echo "cd /app/user/" > /app/.profile.d/home.sh
ONBUILD RUN echo "export PATH=\"$PATH\" GEM_PATH=\"$GEM_PATH\" GEM_HOME=\"$GEM_HOME\" RAILS_ENV=\"\${RAILS_ENV:-$RAILS_ENV}\" SECRET_KEY_BASE=\"\${SECRET_KEY_BASE:-$SECRET_KEY_BASE}\" BUNDLE_APP_CONFIG=\"$BUNDLE_APP_CONFIG\"" > /app/.profile.d/ruby.sh

ENTRYPOINT ["/usr/bin/init.sh"]
