// pages/PostEditorPage/PostEditorPage.tsx
import { useState, useEffect, useMemo, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router';
import { usePost } from '../../hooks/usePost';
import { useUnsavedChangesWarning } from '../../hooks/useUnsavedChangesWarning';
import { useNavigationBlocker } from '../../hooks/useNavigationBlocker';
import { useNotification } from '../../contexts/NotificationContext';
import { Header } from '../../components/common/Header/Header';
import { Button } from '../../components/common/Button/Button';
import { Spinner } from '../../components/common/Spinner/Spinner';
import { ConfirmModal } from '../../components/common/ConfirmModal/ConfirmModal';
import { TitleInput } from '../../components/post/TitleInput/TitleInput';
import { ContentEditor } from '../../components/post/ContentEditor/ContentEditor';
import { validatePost, validateTitleOnly, validateContentOnly } from '../../utils/validation';
import { ApiError, formatErrorMessage } from '../../services/api';
import type { Post } from '../../types/post';
import styles from './PostEditorPage.module.css';

interface PostEditorPageProps {
  mode: 'create' | 'edit';
}

export function PostEditorPage({ mode }: PostEditorPageProps) {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { showNotification } = useNotification();

  // URLパラメータのバリデーション
  const postId = useMemo(() => {
    if (mode === 'create') return undefined;
    if (!id) return undefined;
    const parsed = Number(id);
    if (!Number.isInteger(parsed) || parsed <= 0) {
      return undefined;
    }
    return parsed;
  }, [mode, id]);

  // 編集モードで無効なIDの場合はエラー表示
  useEffect(() => {
    if (mode === 'edit' && !postId) {
      showNotification('error', 'Invalid post ID');
      navigate('/posts/new', { replace: true });
    }
  }, [mode, postId, showNotification, navigate]);

  // フォームデータ
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [published, setPublished] = useState(false);

  // UI状態
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errors, setErrors] = useState<{
    title?: string;
    content?: string;
    general?: string;
  }>({});
  const [showNewPostConfirm, setShowNewPostConfirm] = useState(false);

  // 編集モード: 元データの保持（isDirty判定用）
  const [originalPost, setOriginalPost] = useState<Post | null>(null);

  // usePost hook から投稿データを取得
  const { post, isLoading, error, createPost, updatePost } = usePost({ postId });

  // 新規作成モード: フォームをリセット
  useEffect(() => {
    if (mode === 'create') {
      setTitle('');
      setContent('');
      setPublished(false);
      setOriginalPost(null);
      setErrors({});
    }
  }, [mode]);

  // 編集モード: 取得したデータでフォームを初期化
  useEffect(() => {
    if (post) {
      setTitle(post.title);
      setContent(post.content);
      setPublished(post.published);
      setOriginalPost(post);
    }
  }, [post]);

  // isDirty の計算
  const isDirty = useMemo(() => {
    if (mode === 'create') {
      return title !== '' || content !== '';
    } else {
      if (!originalPost) return false;
      return (
        title !== originalPost.title ||
        content !== originalPost.content ||
        published !== originalPost.published
      );
    }
  }, [mode, title, content, published, originalPost]);

  // 未保存変更警告
  useUnsavedChangesWarning(isDirty && !isSubmitting);
  const { isBlocked, proceed, reset } = useNavigationBlocker(isDirty, isSubmitting);

  // バリデーション
  const handleTitleBlur = useCallback(() => {
    const error = validateTitleOnly(title);
    setErrors((prev) => ({ ...prev, title: error }));
  }, [title]);

  const handleContentBlur = useCallback(() => {
    const error = validateContentOnly(content);
    setErrors((prev) => ({ ...prev, content: error }));
  }, [content]);

  // 下書き保存
  const handleSaveDraft = async () => {
    const result = validatePost(title, content);
    if (!result.isValid) {
      setErrors(result.errors);
      return;
    }

    setIsSubmitting(true);
    try {
      if (mode === 'create') {
        const createdPost = await createPost({ title, content, published: false });
        showNotification('success', '下書きを保存しました');
        navigate(`/posts/${createdPost.id}/edit`, { replace: true });
      } else {
        await updatePost({ title, content, published: false });
        showNotification('success', '下書きを保存しました');
        setOriginalPost({ ...originalPost!, title, content, published: false });
      }
    } catch (e) {
      if (e instanceof ApiError) {
        showNotification('error', formatErrorMessage(e));
      } else {
        showNotification('error', '保存に失敗しました');
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  // 公開
  const handlePublish = async () => {
    const result = validatePost(title, content);
    if (!result.isValid) {
      setErrors(result.errors);
      return;
    }

    setIsSubmitting(true);
    try {
      if (mode === 'create') {
        const createdPost = await createPost({ title, content, published: true });
        showNotification('success', '記事を公開しました');
        navigate(`/posts/${createdPost.id}/edit`, { replace: true });
      } else {
        await updatePost({ title, content, published: true });
        showNotification('success', '記事を公開しました');
        setOriginalPost({ ...originalPost!, title, content, published: true });
      }
    } catch (e) {
      if (e instanceof ApiError) {
        showNotification('error', formatErrorMessage(e));
      } else {
        showNotification('error', '公開に失敗しました');
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  // 新規作成ボタンクリック
  const handleNewPostClick = useCallback(() => {
    if (isDirty) {
      setShowNewPostConfirm(true);
    } else if (mode === 'edit') {
      navigate('/posts/new');
    }
  }, [isDirty, mode, navigate]);

  const handleNewPostConfirm = useCallback(() => {
    setShowNewPostConfirm(false);
    if (mode === 'create') {
      setTitle('');
      setContent('');
      setPublished(false);
      setErrors({});
    } else {
      navigate('/posts/new');
    }
  }, [mode, navigate]);

  const handleNewPostCancel = useCallback(() => {
    setShowNewPostConfirm(false);
  }, []);

  // エラー状態の表示
  if (mode === 'edit' && error) {
    return (
      <>
        <Header activeTab="new" />
        <div className={styles.errorContainer}>
          <p className={styles.errorMessage}>{error}</p>
          <p className={styles.errorHint}>
            URLを直接入力した場合は、URLが正しいか確認してください。
          </p>
          <div className={styles.errorActions}>
            <Button onClick={() => navigate('/posts/new')}>
              新規作成へ
            </Button>
            <Button variant="outline" onClick={() => navigate(-1)}>
              前のページへ戻る
            </Button>
          </div>
        </div>
      </>
    );
  }

  // ローディング状態の表示
  if (mode === 'edit' && isLoading) {
    return (
      <>
        <Header activeTab="new" />
        <main className={styles.main}>
          <div className={styles.loadingContainer}>
            <Spinner size="large" />
            <p>読み込み中...</p>
          </div>
        </main>
      </>
    );
  }

  return (
    <>
      <Header
        activeTab="new"
        onNewPostClick={handleNewPostClick}
        actions={
          <Button
            variant="primary"
            onClick={handlePublish}
            isLoading={isSubmitting}
            disabled={mode === 'create' || isDirty || published}
          >
            公開する
          </Button>
        }
      />
      <main className={styles.main}>
        <div className={styles.contentArea}>
          <TitleInput
            value={title}
            onChange={setTitle}
            error={errors.title}
            onValidate={handleTitleBlur}
            isLoading={mode === 'edit' && isLoading}
          />
          <ContentEditor
            value={content}
            onChange={setContent}
            error={errors.content}
            onValidate={handleContentBlur}
            isLoading={mode === 'edit' && isLoading}
          />
          <div className={styles.editorActions}>
            <Button variant="outline" disabled>
              プレビュー
            </Button>
            <Button
              variant="outline"
              onClick={handleSaveDraft}
              isLoading={isSubmitting}
              disabled={!isDirty}
            >
              下書き保存
            </Button>
          </div>
        </div>
      </main>
      <ConfirmModal
        isOpen={isBlocked}
        title="未保存の変更"
        message="保存されていない変更があります。ページを離れますか？"
        onConfirm={proceed}
        onCancel={reset}
      />
      <ConfirmModal
        isOpen={showNewPostConfirm}
        title="新規作成"
        message="保存されていない変更があります。新しい記事を作成しますか？"
        onConfirm={handleNewPostConfirm}
        onCancel={handleNewPostCancel}
      />
    </>
  );
}
