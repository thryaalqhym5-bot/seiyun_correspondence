const { onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { getStorage } = require("firebase-admin/storage");
const admin = require("firebase-admin");

admin.initializeApp();

// =====================================================
// دالة مساعدة: استخراج مسار الملف من رابط Firebase Storage
// =====================================================
function extractFilePathFromUrl(url) {
  if (!url || typeof url !== "string") return null;

  try {
    const decodedUrl = decodeURIComponent(url);
    const match = decodedUrl.match(/\/o\/(.+?)\?/);
    return match && match[1] ? match[1] : null;
  } catch (error) {
    console.error("خطأ في تحليل الرابط:", url, error);
    return null;
  }
}

// =====================================================
// دالة مساعدة: حذف ملف واحد من Storage بأمان
// =====================================================
async function deleteFileFromStorage(bucket, filePath) {
  try {
    const file = bucket.file(filePath);
    await file.delete();
    console.log(`✅ تم حذف الملف: ${filePath}`);
    return true;
  } catch (error) {
    // 404 = الملف غير موجود مسبقاً — ليس خطأ حقيقياً
    if (error.code === 404) {
      console.log(`⚠️ الملف غير موجود (محذوف مسبقاً): ${filePath}`);
    } else {
      console.error(`❌ خطأ في حذف الملف ${filePath}:`, error.message);
    }
    return false;
  }
}

// =====================================================
// الدالة الرئيسية: تنظيف الملفات اليتيمة (Garbage Collection)
// =====================================================
/**
 * دالة سحابية تعمل تلقائياً في سيرفرات جوجل (Backend)
 * عند حذف مستند من مجموعة "communications"
 *
 * تقوم بمسح جميع الملفات المرتبطة بالمراسلة:
 *  1. ملف الخطاب المُولّد (generated_docx_url)
 *  2. جميع المرفقات الإضافية (attachments[].url)
 */
exports.deleteAttachedFilesOnCommunicationDelete = onDocumentDeleted(
  "communications/{commId}",
  async (event) => {
    const deletedData = event.data.data();
    if (!deletedData) return null;

    const bucket = getStorage().bucket();
    const deletionPromises = [];

    // --- 1. حذف ملف الخطاب المُولّد (DOCX/PDF) ---
    const generatedDocxUrl = deletedData.generated_docx_url;
    if (generatedDocxUrl) {
      const filePath = extractFilePathFromUrl(generatedDocxUrl);
      if (filePath) {
        deletionPromises.push(deleteFileFromStorage(bucket, filePath));
      }
    }

    // --- 2. حذف جميع المرفقات الإضافية ---
    const attachments = deletedData.attachments;
    if (Array.isArray(attachments)) {
      for (const attachment of attachments) {
        const attachmentUrl = attachment.url || attachment.download_url;
        if (attachmentUrl) {
          const filePath = extractFilePathFromUrl(attachmentUrl);
          if (filePath) {
            deletionPromises.push(deleteFileFromStorage(bucket, filePath));
          }
        }
      }
    }

    // --- 3. التحقق من الحقول القديمة (للتوافقية) ---
    const legacyFields = ["pdf_url", "file_url", "attachment_url"];
    for (const field of legacyFields) {
      if (deletedData[field]) {
        const filePath = extractFilePathFromUrl(deletedData[field]);
        if (filePath) {
          deletionPromises.push(deleteFileFromStorage(bucket, filePath));
        }
      }
    }

    if (deletionPromises.length === 0) {
      console.log("لا توجد ملفات مرتبطة بهذه المراسلة. تم التخطي.");
      return null;
    }

    // تنفيذ جميع عمليات الحذف بالتوازي
    const results = await Promise.allSettled(deletionPromises);
    const succeeded = results.filter((r) => r.status === "fulfilled" && r.value === true).length;
    const total = results.length;

    console.log(`🗑️ تم حذف ${succeeded}/${total} ملف مرتبط بالمراسلة ${event.params.commId}`);
    return null;
  }
);

// =====================================================
// دالة: حذف حساب Auth عند حذف مستخدم من Firestore
// =====================================================
exports.deleteAuthUserOnFirestoreDelete = onDocumentDeleted("users/{userId}", async (event) => {
  const userId = event.params.userId;
  
  if (!userId) return;

  try {
    await admin.auth().deleteUser(userId);
    console.log(`✅ تم حذف حساب Firebase Auth للمستخدم: ${userId}`);
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      console.log(`ℹ️ حساب Firebase Auth غير موجود مسبقاً للمستخدم: ${userId}`);
    } else {
      console.error(`❌ خطأ أثناء حذف حساب Firebase Auth: ${userId}`, error);
    }
  }
});
