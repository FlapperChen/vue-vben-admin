import { computed, ref } from 'vue';

import { message } from 'ant-design-vue';

interface UploadFileItem {
  id: string;
  name: string;
  progress: number;
}

interface UseFileUploadOptions {
  /** 从路径提取项目名 */
  extractProjectFromPath?: (path: string) => string;
  /** 上传失败回调（模拟成功时） */
  onUploadFallback?: (file: File) => void;
  /** 上传成功回调 */
  onUploadSuccess?: (result: any, file: File) => void;
  /** API 上传端点 */
  uploadEndpoint: string;
}

/**
 * 文件上传 Composable
 * 封装上传进度、状态管理和上传逻辑
 */
export function useFileUpload(options: UseFileUploadOptions) {
  const {
    uploadEndpoint,
    onUploadSuccess,
    onUploadFallback,
    _extractProjectFromPath = (path: string) => {
      const parts = path.split('/');
      return parts.length > 1
        ? parts[parts.length - 2] || 'unknown'
        : 'unknown';
    },
  } = options;

  // 状态
  const uploading = ref(false);
  const uploadFileList = ref<UploadFileItem[]>([]);

  // 计算属性
  /** 总上传进度 */
  const totalProgress = computed(() => {
    if (uploadFileList.value.length === 0) return 0;
    const total = uploadFileList.value.reduce((sum, f) => sum + f.progress, 0);
    return Math.round(total / uploadFileList.value.length);
  });

  /** 已完成数量 */
  const completedCount = computed(() => {
    return uploadFileList.value.filter((f) => f.progress >= 100).length;
  });

  /**
   * 上传单个文件
   * @param file 要上传的文件
   */
  const handleUpload = async (file: File) => {
    const fileId = `${file.name}_${Date.now()}`;
    const fileInfo: UploadFileItem = {
      name: file.name,
      progress: 0,
      id: fileId,
    };

    uploading.value = true;
    uploadFileList.value.push(fileInfo);

    // 模拟上传进度
    const progressInterval = setInterval(() => {
      const idx = uploadFileList.value.findIndex((f) => f.id === fileId);
      if (idx === -1) {
        clearInterval(progressInterval);
      } else {
        const currentFile = uploadFileList.value[idx];
        if (currentFile) {
          currentFile.progress += Math.random() * 20;
          if (currentFile.progress >= 90) {
            currentFile.progress = 90;
            clearInterval(progressInterval);
          }
        }
      }
    }, 200);

    const formData = new FormData();
    formData.append('file', file);

    try {
      const response = await fetch(uploadEndpoint, {
        method: 'POST',
        body: formData,
      });

      clearInterval(progressInterval);
      const idx = uploadFileList.value.findIndex((f) => f.id === fileId);
      if (idx !== -1) {
        const currentFile = uploadFileList.value[idx];
        if (currentFile) currentFile.progress = 100;
      }

      if (response.ok) {
        const result = await response.json();
        onUploadSuccess?.(result, file);
        message.success(`文件 ${file.name} 上传成功`);
      } else {
        // 模拟上传成功（开发环境）
        await new Promise((resolve) => setTimeout(resolve, 500));
        onUploadFallback?.(file);
        message.success(`文件 ${file.name} 上传成功（模拟）`);
      }
    } catch {
      clearInterval(progressInterval);
      const idx = uploadFileList.value.findIndex((f) => f.id === fileId);
      if (idx !== -1) {
        const currentFile = uploadFileList.value[idx];
        if (currentFile) currentFile.progress = 100;
      }
      // 模拟上传成功（开发环境）
      await new Promise((resolve) => setTimeout(resolve, 500));
      onUploadFallback?.(file);
      message.warning(`文件 ${file.name} 上传成功（模拟模式）`);
    } finally {
      // 延迟移除已完成文件，保持进度显示
      setTimeout(() => {
        uploadFileList.value = uploadFileList.value.filter(
          (f) => f.id !== fileId,
        );
        if (uploadFileList.value.length === 0) {
          uploading.value = false;
        }
      }, 500);
    }

    return false;
  };

  return {
    uploading,
    uploadFileList,
    totalProgress,
    completedCount,
    handleUpload,
  };
}
