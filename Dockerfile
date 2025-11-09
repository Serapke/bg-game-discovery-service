FROM ruby:3.3.7-alpine

# Install dependencies
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    tzdata \
    bash \
    yaml-dev

# Set working directory
WORKDIR /app

# Install bundler
RUN gem install bundler

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle install

# Copy application code
COPY . .

# Expose port
EXPOSE 3002

# Default command (can be overridden)
CMD ["rails", "server", "-b", "0.0.0.0", "-p", "3002"]