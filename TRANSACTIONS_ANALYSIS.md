# Phân Tích & Đề Xuất Sử Dụng Transaction Trong Hệ Thống GameFit

Tài liệu này tổng hợp phân tích về toàn bộ cấu trúc Cơ sở dữ liệu, Stored Procedures và Backend Services của hệ thống GameFit nhằm xác định các chức năng/nghiệp vụ bắt buộc hoặc khuyến nghị sử dụng **Transaction** để đảm bảo tính toàn vẹn dữ liệu (**ACID**).

---

## 1. Cơ Sở & Tiêu Chí Xác Định Cần Dùng Transaction

Một chức năng **bắt buộc hoặc rất cần** sử dụng Transaction khi thỏa mãn ít nhất một trong các tiêu chí sau:
1. **Tính nguyên tử (Atomicity):** Nghiệp vụ bao gồm từ **2 câu lệnh ghi (INSERT / UPDATE / DELETE) trở lên** phụ thuộc lẫn nhau. Nếu một thao tác thất bại thì toàn bộ các thao tác trước đó phải được hoàn tác (`ROLLBACK`).
2. **Ngăn chặn dữ liệu mồ côi (Orphaned / Dirty Data):** Các bảng có liên kết logic đa hình (Polymorphic FK như bảng `Votes` không có `FOREIGN KEY ... ON DELETE CASCADE`) cần dọn dẹp đồng thời khi bản ghi cha bị xóa.
3. **Ràng buộc phụ thuộc giữa Xóa và Thêm mới:** Thao tác cập nhật theo cơ chế `DELETE` dữ liệu cũ rồi `INSERT` dữ liệu mới (ví dụ cập nhật danh sách Tags).
4. **Đồng bộ hóa nghiệp vụ:** Cập nhật trạng thái thực thể kết hợp tạo thông báo (`Notifications`) hoặc xử lý kỷ luật/khóa tài khoản (`Users`).

---

## 2. Chi Tiết Các Tính Năng Cần Áp Dụng Transaction

### 🔴 Mức độ 1: CỰC KỲ QUAN TRỌNG (Bắt buộc phải có)

#### 1. Cập nhật Game (`sp_updateGame` & `games.service.js`)
* **Các bảng ảnh hưởng:** `Games`, `Games_Tags`.
* **Hiện trạng trong hệ thống:**
  - Trong `sp_updateGame`:
    1. Cập nhật thông tin game: `UPDATE Games ...`
    2. Xóa toàn bộ tag cũ: `DELETE FROM Games_Tags WHERE game_id = @game_id;`
    3. Thêm lại tag mới từ chuỗi phân tách: `INSERT INTO Games_Tags ... SELECT STRING_SPLIT(@name_tag, ',');`
  - Trong `games.service.js` (fallback query): chạy các lệnh cập nhật ảnh `UPDATE Games SET image = ...` và xóa/thêm tags bằng các query Node.js rời rạc.
* **Rủi ro khi thiếu Transaction:**
  - Nếu bước 3 gặp lỗi (chuỗi tag chứa ký tự không hợp lệ, đứt kết nối mạng giữa server và CSDL, hoặc lỗi ràng buộc), bước `DELETE` ở bước 2 đã thực thi thành công.
  - **Hậu quả:** Toàn bộ thể loại/tag của game bị **xóa trắng vĩnh viễn**, game bị biến mất khỏi các bộ lọc danh mục ngoài giao diện người dùng.
* **Đề xuất khắc phục (T-SQL):**
  ```sql
  CREATE OR ALTER PROCEDURE sp_updateGame
      @game_id INT,
      @name NVARCHAR(255),
      @name_tag NVARCHAR(MAX),
      @developer NVARCHAR(255),
      @is_active BIT
  AS
  BEGIN
      SET NOCOUNT ON;
      BEGIN TRY
          BEGIN TRANSACTION;

          UPDATE Games
          SET name = @name,
              developer = @developer,
              is_active = @is_active
          WHERE game_id = @game_id;

          IF @name_tag IS NOT NULL
          BEGIN
              DELETE FROM Games_Tags WHERE game_id = @game_id;

              INSERT INTO Games_Tags (game_id, tag_id)
              SELECT DISTINCT @game_id, t.tag_id
              FROM Tags t
              INNER JOIN STRING_SPLIT(@name_tag, ',') s 
                  ON LOWER(LTRIM(RTRIM(s.value))) = LOWER(LTRIM(RTRIM(t.name)));
          END

          COMMIT TRANSACTION;
      END TRY
      BEGIN CATCH
          IF @@TRANCOUNT > 0
              ROLLBACK TRANSACTION;
          DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
          RAISERROR(@ErrMsg, 16, 1);
      END CATCH;
  END;
  GO
  ```

---

#### 2. Xóa Game hoàn toàn (`deleteGame` trong `games.service.js`)
* **Các bảng ảnh hưởng:** `Wishlist`, `Games_Tags`, `Game_requirement`, `Reviews`, `Games`.
* **Hiện trạng trong hệ thống:**
  - Trong `games.service.js` (dòng 360 - 396), khi xóa game mà vướng lỗi khóa ngoại (FK), backend thực hiện vòng lặp xóa thủ công từng bảng liên quan qua 5-6 query rời rạc:
    ```javascript
    const tablesToDeleteFrom = [
      "Wishlist", "Games_Tags", "Game_requirement", "Reviews"
    ];
    for (const table of tablesToDeleteFrom) {
      await reqDel.query(`DELETE FROM ${table} WHERE game_id = @game_id`);
    }
    await reqFinal.query("DELETE FROM Games WHERE game_id = @game_id");
    ```
* **Rủi ro khi thiếu Transaction:**
  - Nếu quá trình xóa gặp lỗi ở giữa (ví dụ xóa được `Wishlist` và `Games_Tags` nhưng lỗi ở `Reviews`), dữ liệu rơi vào trạng thái nửa vời: người dùng mất wishlist, game mất tags, nhưng game và review vẫn còn.
* **Đề xuất khắc phục (Node.js mssql Transaction):**
  ```javascript
  const transaction = new sql.Transaction(pool);
  await transaction.begin();
  try {
    const req = new sql.Request(transaction);
    req.input("game_id", sql.Int, validId);
    
    await req.query("DELETE FROM Wishlist WHERE game_id = @game_id");
    await req.query("DELETE FROM Games_Tags WHERE game_id = @game_id");
    await req.query("DELETE FROM Game_requirement WHERE game_id = @game_id");
    await req.query("DELETE FROM Reviews WHERE game_id = @game_id");
    await req.query("DELETE FROM Games WHERE game_id = @game_id");

    await transaction.commit();
  } catch (err) {
    await transaction.rollback();
    throw err;
  }
  ```

---

### 🟡 Mức độ 2: QUAN TRỌNG (Khuyến nghị áp dụng)

#### 3. Thêm mới Game (`sp_addGame`)
* **Các bảng ảnh hưởng:** `Games`, `Games_Tags`.
* **Hiện trạng:**
  1. `INSERT INTO Games(...)` -> lấy `SCOPE_IDENTITY() AS @game_id`.
  2. `INSERT INTO Games_Tags(game_id, tag_id) ...`
* **Rủi ro khi thiếu Transaction:**
  - Nếu việc insert tags bị lỗi cú pháp chuỗi hoặc lỗi kết nối, game vẫn được tạo trong bảng `Games` nhưng không có bất kỳ tag nào (Game rỗng danh mục).
* **Đề xuất khắc phục:** Bọc 2 lệnh `INSERT` trong `BEGIN TRANSACTION ... COMMIT TRANSACTION`. Nếu thêm tag thất bại, rollback việc tạo Game.

---

#### 4. Xóa Đánh giá (`sp_DeleteReview`) & Dọn dẹp Lượt Vote (`Votes`)
* **Các bảng ảnh hưởng:** `Reviews`, `Votes`.
* **Hiện trạng:**
  - Bảng `Votes` sử dụng khóa ngoại động: `target_type` (`'REVIEW'` / `'RECOMMENDATION'`) và `target_id`.
  - Do `target_id` không có ràng buộc `FOREIGN KEY` cứng, nên không thể cấu hình `ON DELETE CASCADE`.
  - `sp_DeleteReview` hiện tại chỉ xóa trong bảng `Reviews`.
* **Rủi ro khi thiếu Transaction:**
  - Các lượt vote của đánh giá này vẫn nằm lại trong bảng `Votes`, trở thành **dữ liệu rác/mồ côi**.
* **Đề xuất khắc phục:**
  ```sql
  CREATE OR ALTER PROCEDURE sp_DeleteReview
      @user_id INT,
      @game_id INT
  AS
  BEGIN
      SET NOCOUNT ON;
      DECLARE @review_id INT;
      SELECT @review_id = review_id FROM Reviews WHERE user_id = @user_id AND game_id = @game_id;

      IF @review_id IS NOT NULL
      BEGIN
          BEGIN TRY
              BEGIN TRANSACTION;
              -- 1. Xóa các lượt Vote của Review này trước
              DELETE FROM Votes WHERE target_type = 'REVIEW' AND target_id = @review_id;
              -- 2. Xóa chính Review đó
              DELETE FROM Reviews WHERE review_id = @review_id;
              COMMIT TRANSACTION;
          END TRY
          BEGIN CATCH
              IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
              THROW;
          END CATCH;
      END
  END;
  GO
  ```

---

#### 5. Xóa / Ẩn Cấu hình máy tính cá nhân (`User_pc`) & Đề xuất cấu hình (`Game_PC_Recommendation`)
* **Các bảng ảnh hưởng:** `User_pc`, `Game_PC_Recommendation`, `Votes`.
* **Hiện trạng:**
  - Khi người dùng xóa cấu hình PC (`sp_DeleteComputerConfig`), trigger `trg_UserPC_InsteadOfDelete` chuyển `is_deleted = 1`.
* **Rủi ro:**
  - Dàn máy đã bị ẩn khỏi danh sách máy của người dùng, nhưng các bài viết đề xuất cấu hình cho game (`Game_PC_Recommendation`) dùng `pc_id` này vẫn có thể hiển thị nếu không được cập nhật `is_hidden = 1` đồng bộ.
* **Đề xuất:** Gom việc đánh dấu `is_deleted = 1` của `User_pc` và `is_hidden = 1` của `Game_PC_Recommendation` vào một Transaction.

---

#### 6. Kiểm duyệt vi phạm đánh giá & Xử phạt người dùng (`sp_ModerateReview`)
* **Các bảng ảnh hưởng:** `Reviews`, `Notifications`, `Users`.
* **Kịch bản:**
  1. Admin duyệt báo cáo vi phạm (`action = 'HIDE'`).
  2. Đánh dấu `is_hidden = 1` và `report_status = 'HIDDEN'` trên `Reviews`.
  3. Tự động thêm 1 thông báo vào bảng `Notifications` cho người dùng: *"Bình luận của bạn trên game X đã bị ẩn do vi phạm quy tắc cộng đồng."*
  4. Nếu người dùng vi phạm lần thứ 3 trở lên, tự động cập nhật `status = 'Locked'` trên bảng `Users`.
* **Lý do cần Transaction:**
  - Đảm bảo tính nguyên tử giữa việc kiểm duyệt, gửi thông báo và thi hành kỷ luật tài khoản.

---

#### 7. Đăng ký tài khoản (`sp_Register`)
* **Các bảng ảnh hưởng:** `Users`, `Notifications`.
* **Hiện trạng:**
  - `sp_Register` hiện chỉ thực hiện `INSERT INTO Users`.
* **Khuyến nghị mở rộng:**
  - Khi mở rộng thêm các thao tác khởi tạo ban đầu cho thành viên mới (như tự động tạo thông báo chào mừng trong `Notifications`, cấu hình phân quyền hoặc thiết lập hồ sơ mặc định), cần bao bọc toàn bộ chuỗi tạo này trong Transaction.

---

## 3. Các Tính Năng Đã Triển Khai Tốt Transaction Trong Hệ Thống

Hệ thống đã có một số Stored Procedure được thiết kế chuẩn mực với đầy đủ `BEGIN TRY ... BEGIN TRANSACTION ... COMMIT ... ROLLBACK`:

1. **`sp_AdminAddUser`** ([`sql/sp/auth.sql`](file:///d:/ARSENE/HCMUTE/Ki5/CNPM/project_code/GameFit/sql/sp/auth.sql#L1-L63)): Kiểm tra trùng lặp email/username, kiểm tra role và tạo tài khoản an toàn.
2. **`sp_ChangeUserRole`** ([`sql/sp/auth.sql`](file:///d:/ARSENE/HCMUTE/Ki5/CNPM/project_code/GameFit/sql/sp/auth.sql#L67-L107)): Kiểm tra tồn tại user, xác thực role và cập nhật quyền hạn trong Transaction.
3. **`sp_LockUnlockUser`** ([`sql/sp/auth.sql`](file:///d:/ARSENE/HCMUTE/Ki5/CNPM/project_code/GameFit/sql/sp/auth.sql#L109-L145)): Cập nhật trạng thái khóa/mở khóa tài khoản cùng lý do và thời hạn khóa an toàn.

---

## 4. Bảng Tổng Hợp Khuyến Nghị

| STT | Nghiệp vụ / Tính năng | Bảng CSDL liên quan | Ưu tiên | Lý do chính |
| :---: | :--- | :--- | :---: | :--- |
| **1** | **Cập nhật thông tin Game** (`sp_updateGame`) | `Games`, `Games_Tags` | 🔴 **Bắt buộc** | Tránh rủi ro xóa mất toàn bộ tags của game nếu bước insert mới bị lỗi. |
| **2** | **Xóa Game** (`deleteGame`) | `Games`, `Games_Tags`, `Game_requirement`, `Reviews`, `Wishlist` | 🔴 **Bắt buộc** | Vòng lặp xóa nhiều bảng rời rạc; lỗi giữa chừng sẽ gây phân mảnh và dirty data. |
| **3** | **Thêm Game mới** (`sp_addGame`) | `Games`, `Games_Tags` | 🟡 **Nên có** | Đảm bảo thông tin game và thể loại/tags luôn đi kèm nguyên vẹn. |
| **4** | **Xóa Đánh giá** (`sp_DeleteReview`) | `Reviews`, `Votes` | 🟡 **Nên có** | Dọn dẹp sạch các lượt vote liên quan do `Votes` không có FK cascade. |
| **5** | **Xóa / Ẩn Cấu hình PC** | `User_pc`, `Game_PC_Recommendation` | 🟡 **Nên có** | Đồng bộ trạng thái ẩn giữa dàn máy cá nhân và các bài đăng đề xuất cấu hình. |
| **6** | **Kiểm duyệt Đánh giá vi phạm** | `Reviews`, `Notifications`, `Users` | 🟡 **Nên có** | Đảm bảo đồng bộ giữa ẩn bình luận, gửi thông báo và khóa tài khoản vi phạm. |
| **7** | **Đăng ký tài khoản** (`sp_Register`) | `Users`, `Notifications` | 🟢 **Mở rộng** | Đảm bảo khởi tạo dữ liệu tài khoản và thông báo chào mừng ban đầu. |
