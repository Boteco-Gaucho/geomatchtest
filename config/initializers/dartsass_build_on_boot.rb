return unless Rails.env.development?

# In dev, it’s common to run only `rails s` (without `bin/dev`).
# With Propshaft, the layout expects `application.css`, which should be generated
# from `app/assets/stylesheets/application.scss` by dartsass-rails into `app/assets/builds/application.css`.
#
# This initializer makes the dev experience smoother by ensuring the CSS build exists
# (and is up to date) when the app boots.
Rails.application.config.after_initialize do
  begin
    builds_dir = Rails.root.join("app/assets/builds")
    builds_dir.mkpath

    input = Rails.root.join("app/assets/stylesheets/application.scss")
    output = builds_dir.join("application.css")

    next unless input.exist?

    needs_build =
      !output.exist? ||
      output.mtime < input.mtime

    next unless needs_build

    require "rake"
    Rails.application.load_tasks unless Rake::Task.task_defined?("dartsass:build")

    # `invoke` runs only once per process; that's fine for boot-time build.
    Rake::Task["dartsass:build"].invoke
  rescue => e
    Rails.logger.warn("[dartsass_build_on_boot] Could not build application.css: #{e.class}: #{e.message}")
  end
end


