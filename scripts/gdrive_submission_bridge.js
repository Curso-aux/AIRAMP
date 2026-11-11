/**
 * AIRAMP Google Drive Automated Submission Bridge
 * ==============================================================
 * Deployed under your Google Account (e.g. betajhoneilpoblacion@gmail.com)
 * Automatically receives student assignment files from AIRAMP and drops them 
 * directly into the target Google Drive folder provided by the teacher!
 * 
 * Deployment Instructions (Takes 60 seconds):
 * 1. Go to https://script.google.com while signed in to your Google Account.
 * 2. Click "New project" and name it "AIRAMP Drive Bridge".
 * 3. Replace all default code with this entire script.
 * 4. Click "Deploy" -> "New deployment".
 * 5. Under "Select type" (gear icon), choose "Web app".
 * 6. Set:
 *    - Description: AIRAMP Student File Router
 *    - Execute as: Me (your email)
 *    - Who has access: Anyone
 * 7. Click "Deploy" -> Authorize access with your Google account.
 * 8. Copy the "Web app URL" (e.g. https://script.google.com/macros/s/.../exec).
 * ==============================================================
 */

function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      return jsonResponse({
        status: "error",
        message: "No POST body received."
      });
    }

    var data = JSON.parse(e.postData.contents);
    var targetFolder = null;
    var folderId = data.folderId;

    // 1. If a folderId or folderUrl was provided, attempt to locate it
    if (folderId) {
      try {
        // Strip query params or URLs if passed
        var cleanId = extractFolderId(folderId);
        if (cleanId) {
          targetFolder = DriveApp.getFolderById(cleanId);
        }
      } catch (err) {
        // Target folder was not accessible or invalid; fallback to default
      }
    }

    // 2. Fallback to default AIRAMP folder in your 5TB Drive if folder wasn't found
    if (!targetFolder) {
      var defaultFolderName = "AIRAMP_Student_Submissions";
      var folders = DriveApp.getFoldersByName(defaultFolderName);
      targetFolder = folders.hasNext() ? folders.next() : DriveApp.createFolder(defaultFolderName);
    }

    // 3. Format clean filename: [Section] [Student Name] - [OriginalFileName]
    var sectionPart = data.section ? "[" + data.section + "] " : "";
    var studentPart = data.studentName ? data.studentName + " - " : "";
    var originalName = data.fileName || "submission.pdf";
    var finalFileName = sectionPart + studentPart + originalName;

    // 4. Decode base64 payload into binary blob
    var fileBytes = Utilities.base64Decode(data.bytes);
    var mimeType = data.mimeType || "application/octet-stream";
    var blob = Utilities.newBlob(fileBytes, mimeType, finalFileName);

    // 5. Create file inside target folder
    var createdFile = targetFolder.createFile(blob);

    // 6. Set public view permission so teacher and student can preview with link
    try {
      createdFile.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
    } catch (_) {}

    var fileId = createdFile.getId();
    var viewUrl = createdFile.getUrl();
    var downloadUrl = "https://drive.google.com/uc?export=download&id=" + fileId;

    return jsonResponse({
      status: "success",
      fileId: fileId,
      fileName: finalFileName,
      folderName: targetFolder.getName(),
      viewUrl: viewUrl,
      downloadUrl: downloadUrl
    });

  } catch (error) {
    return jsonResponse({
      status: "error",
      message: error.toString()
    });
  }
}

function doGet(e) {
  return jsonResponse({
    status: "online",
    service: "AIRAMP Google Drive Submission Bridge",
    account: Session.getActiveUser().getEmail(),
    time: new Date().toISOString()
  });
}

function extractFolderId(input) {
  if (!input) return "";
  input = input.trim();
  // If it's already an ID
  if (input.indexOf("/") === -1 && input.length >= 15) return input;
  // Match /folders/([a-zA-Z0-9_-]+)
  var match = input.match(/\/folders\/([a-zA-Z0-9_-]+)/);
  if (match && match[1]) return match[1];
  // Match id=([a-zA-Z0-9_-]+)
  var idMatch = input.match(/[?&]id=([a-zA-Z0-9_-]+)/);
  if (idMatch && idMatch[1]) return idMatch[1];
  return input;
}

function jsonResponse(data) {
  return ContentService.createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}
