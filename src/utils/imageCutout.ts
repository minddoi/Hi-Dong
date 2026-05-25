export function fileToBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();

    reader.onload = () => {
      if (typeof reader.result === 'string') {
        resolve(reader.result);
      } else {
        reject(new Error('이미지를 읽을 수 없습니다.'));
      }
    };

    reader.onerror = () => reject(new Error('이미지를 읽는 중 오류가 발생했습니다.'));
    reader.readAsDataURL(file);
  });
}

export async function removeBackgroundFromImage(file: File): Promise<string> {
  const { removeBackground } = await import('@imgly/background-removal');
  const imageBlob = await removeBackground(file);

  return new Promise((resolve, reject) => {
    const reader = new FileReader();

    reader.onload = () => {
      if (typeof reader.result === 'string') {
        resolve(reader.result);
      } else {
        reject(new Error('누끼 이미지를 변환할 수 없습니다.'));
      }
    };

    reader.onerror = () => reject(new Error('누끼 이미지를 읽는 중 오류가 발생했습니다.'));
    reader.readAsDataURL(imageBlob);
  });
}
