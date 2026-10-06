class AddDraftArticleTokenToUsers < ActiveRecord::Migration[6.0]
  def up
    add_column :users, :draft_article_token, :string
    add_index :users, :draft_article_token, unique: true      # due utenti non devono mai avere lo stesso token

    # Gli utenti che ESISTONO già ricevono subito un token (i nuovi lo avranno da has_secure_token).
    # Il libro lo fa dopo, a mano dalla console con regenerate_draft_article_token.
    select_values("SELECT id FROM users").each do |id|
      execute "UPDATE users SET draft_article_token = #{quote(SecureRandom.base58(24))} WHERE id = #{id.to_i}"
    end
  end

  def down
    remove_index :users, :draft_article_token
    remove_column :users, :draft_article_token
  end
end
