ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def app
    Sinatra::Application
  end

  def test_index
    create_document('changes.txt')
    create_document('markdown.md')

    get '/'

    assert_equal 200, last_response.status
    assert_equal  'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'changes.txt'
    assert_includes last_response.body, 'markdown.md'
    assert_includes last_response.body, %q(<button type="submit")
    assert_includes last_response.body, 'Delete'

    assert_includes last_response.body, 'New Document'
    assert_includes last_response.body, 'Sign in'
  end

  def test_viewing_text_document
    create_document('changes.txt',"Hello World!")

    get '/changes.txt'

    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_equal "Hello World!", last_response.body
  end

  def test_viewing_markdown_document
    markdown = '#This is a title!'
    create_document('markdown.md', markdown)
    expected_output = render_markdown(markdown)

    get '/markdown.md'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, expected_output
  end

  def test_unsupported_format_request
    create_document('test.random')

    get '/test.random'

    assert_equal 200, last_response.status
    assert_includes last_response.body, '.random file format not supported...'
  end

  def test_document_not_found
    get '/bad_doc_path.txt'
    assert_equal 302, last_response.status

    assert_equal 'bad_doc_path.txt does not exist.', session[:message]
  end

  def test_editing_document
    create_document('changes.txt', 'Text to edit')

    get '/changes.txt/edit'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Edit content of changes.txt:'
    assert_includes last_response.body, 'Text to edit'
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_document
    create_document('changes.txt')

    post '/changes.txt', content: 'new content'

    assert_equal 302, last_response.status
    assert_equal 'changes.txt has been updated', session[:message]

    get '/changes.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_new_document_form
    get '/new'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Add a new document:'
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_creating_doc
    file_name = 'test_new.doc'
    file_path = File.join(data_path, file_name)
    post '/new', file_name: file_name

    assert_equal 302, last_response.status
    assert_equal 'test_new.doc was created.', session[:message]

    get '/'
    assert_includes last_response.body, 'test_new.doc'

    assert File.exist?(file_path)
  end

  def test_empty_file_name_not_created
    post '/new', file_name: '      '

    assert_equal 422, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'A name is required.'
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_deleting_doc
    create_document('changes.txt')
    create_document('markdown.md')
    file_path = File.join(data_path, 'changes.txt')

    post '/changes.txt/destroy'
    assert_equal 302, last_response.status
    assert_equal 'changes.txt has been deleted.', session[:message]

    refute File.exist?(file_path)
  end

  def test_signin_form
    get '/users/signin'

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Username'
    assert_includes last_response.body, 'Password'
    assert_includes last_response.body, %q(<button type="submit")
    assert_includes last_response.body, 'Sign In'
  end

  def test_signing_in
    post '/users/signin', username: 'admin', password: 'secret'
    assert_equal 302, last_response.status
    assert_equal 'Welcome!', session[:message]
    assert_equal 'admin', session[:username]

    get last_response["Location"]
    assert_includes last_response.body, 'Signed in as admin'
    assert_includes last_response.body, 'Signout'
  end

  def test_signin_with_bad_credentials
    post "/users/signin", username: "guest", password: "shhhh"
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, 'Invalid credentials'
  end

  def test_signout
    get '/', {}, { "rack.session" => { username: 'admin' } }
    assert_includes last_response.body, 'Signed in as admin'

    post '/users/signout'
    assert_equal 'You have been signed out.', session[:message]

    get last_response['Location']
    assert_nil session[:username]
    assert_includes last_response.body, 'Sign in'
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end
end
