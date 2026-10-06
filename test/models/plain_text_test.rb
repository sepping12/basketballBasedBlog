require 'test_helper'

class PlainTextTest < ActiveSupport::TestCase
  test "una riga vuota separa i paragrafi, un a-capo semplice diventa <br>" do
    assert_equal "<p>Primo.</p><p>Secondo<br>su due righe</p>", PlainText.to_html("Primo.\n\nSecondo\nsu due righe")
  end

  test "l'HTML nel testo è neutralizzato" do
    assert_equal "<p>&lt;b&gt;no&lt;/b&gt; &amp; sì</p>", PlainText.to_html("<b>no</b> & sì")
  end

  test "gli a-capo di Windows e gli spazi extra non danno problemi" do
    assert_equal "<p>uno</p><p>due</p>", PlainText.to_html("  uno \r\n\r\n due  ")
  end

  test "più righe vuote contano come una" do
    assert_equal "<p>a</p><p>b</p>", PlainText.to_html("a\n\n\n\nb")
  end

  test "testo vuoto o nil → stringa vuota" do
    assert_equal "", PlainText.to_html(nil)
    assert_equal "", PlainText.to_html("  \n ")
  end
end
