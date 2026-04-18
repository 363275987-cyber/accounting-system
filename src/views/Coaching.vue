<template>
  <div>
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800">🏓 教练系统</h1>
    </div>

    <!-- Tabs -->
    <div class="flex gap-1 mb-6 bg-gray-100 rounded-lg p-1">
      <button
        v-for="tab in tabs"
        :key="tab.key"
        @click="activeTab = tab.key"
        class="px-4 py-2 rounded-md text-sm font-medium transition"
        :class="activeTab === tab.key ? 'bg-white text-blue-600 shadow-sm' : 'text-gray-500 hover:text-gray-700'"
      >
        {{ tab.label }}
      </button>
    </div>

    <!-- ==================== 教练 Tab ==================== -->
    <div v-if="activeTab === 'coaches'">
      <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex gap-3 items-center flex-wrap">
        <input v-model="coachSearch" placeholder="🔍 搜索教练..." class="px-3 py-2 border border-gray-200 rounded-lg text-sm w-60 outline-none focus:ring-2 focus:ring-blue-500">
        <span class="text-sm text-gray-500 ml-auto">共 {{ filteredCoaches.length }} 位教练</span>
        <button @click="openCoachModal()" class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition"><Icon name="plus" class="inline w-4 h-4 -mt-0.5 mr-1" /> 添加教练</button>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
        <table class="w-full text-sm">
          <thead class="bg-gray-50 text-gray-500 text-left">
            <tr>
              <th class="px-4 py-3 font-medium">姓名</th>
              <th class="px-4 py-3 font-medium">电话</th>
              <th class="px-4 py-3 font-medium">擅长领域</th>
              <th class="px-4 py-3 font-medium">课时费</th>
              <th class="px-4 py-3 font-medium">状态</th>
              <th class="px-4 py-3 font-medium text-right">操作</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-50">
            <tr v-for="c in filteredCoaches" :key="c.id" class="hover:bg-gray-50 transition">
              <td class="px-4 py-3 font-medium text-gray-800">{{ c.name }}</td>
              <td class="px-4 py-3 text-gray-500">{{ c.phone || '-' }}</td>
              <td class="px-4 py-3">
                <span v-for="s in parseJson(c.specialties)" :key="s" class="inline-block text-xs bg-blue-50 text-blue-600 px-2 py-0.5 rounded-full mr-1">{{ s }}</span>
                <span v-if="!c.specialties || parseJson(c.specialties).length === 0" class="text-gray-500">-</span>
              </td>
              <td class="px-4 py-3 text-gray-700">¥{{ c.hourly_rate }}<span class="text-gray-500 text-xs">/h</span></td>
              <td class="px-4 py-3">
                <span class="text-xs px-2 py-0.5 rounded-full" :class="c.status === 'active' ? 'text-green-600 bg-green-50' : 'text-gray-500 bg-gray-100'">
                  {{ c.status === 'active' ? '✅ 在职' : '⏸️ 停用' }}
                </span>
              </td>
              <td class="px-4 py-3 text-right">
                <button @click="openCoachModal(c)" class="text-blue-600 hover:text-blue-800 text-xs mr-2">编辑</button>
              </td>
            </tr>
            <tr v-if="filteredCoaches.length === 0">
              <td colspan="6" class="px-4 py-8 text-center text-gray-500">暂无教练数据</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ==================== 学员 Tab ==================== -->
    <div v-if="activeTab === 'students'">
      <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex gap-3 items-center flex-wrap">
        <input v-model="studentSearch" placeholder="🔍 搜索学员..." class="px-3 py-2 border border-gray-200 rounded-lg text-sm w-60 outline-none focus:ring-2 focus:ring-blue-500">
        <span class="text-sm text-gray-500 ml-auto">共 {{ filteredStudents.length }} 位学员</span>
        <button @click="openStudentModal()" class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition"><Icon name="plus" class="inline w-4 h-4 -mt-0.5 mr-1" /> 添加学员</button>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
        <table class="w-full text-sm">
          <thead class="bg-gray-50 text-gray-500 text-left">
            <tr>
              <th class="px-4 py-3 font-medium">姓名</th>
              <th class="px-4 py-3 font-medium">电话</th>
              <th class="px-4 py-3 font-medium">球技水平</th>
              <th class="px-4 py-3 font-medium">备注</th>
              <th class="px-4 py-3 font-medium text-right">操作</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-50">
            <tr v-for="s in filteredStudents" :key="s.id" class="hover:bg-gray-50 transition">
              <td class="px-4 py-3 font-medium text-gray-800">{{ s.name }}</td>
              <td class="px-4 py-3 text-gray-500">{{ s.phone || '-' }}</td>
              <td class="px-4 py-3">
                <span class="text-xs px-2 py-0.5 rounded-full" :class="levelClass(s.level)">
                  {{ levelLabel(s.level) }}
                </span>
              </td>
              <td class="px-4 py-3 text-gray-500 max-w-xs truncate">{{ s.note || '-' }}</td>
              <td class="px-4 py-3 text-right">
                <button @click="openStudentModal(s)" class="text-blue-600 hover:text-blue-800 text-xs mr-2">编辑</button>
              </td>
            </tr>
            <tr v-if="filteredStudents.length === 0">
              <td colspan="5" class="px-4 py-8 text-center text-gray-500">暂无学员数据</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ==================== 课程 Tab ==================== -->
    <div v-if="activeTab === 'courses'">
      <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex gap-3 items-center flex-wrap">
        <input v-model="courseSearch" placeholder="🔍 搜索课程..." class="px-3 py-2 border border-gray-200 rounded-lg text-sm w-60 outline-none focus:ring-2 focus:ring-blue-500">
        <span class="text-sm text-gray-500 ml-auto">共 {{ filteredCourses.length }} 门课程</span>
        <button @click="openCourseModal()" class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition"><Icon name="plus" class="inline w-4 h-4 -mt-0.5 mr-1" /> 添加课程</button>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
        <table class="w-full text-sm">
          <thead class="bg-gray-50 text-gray-500 text-left">
            <tr>
              <th class="px-4 py-3 font-medium">课程名称</th>
              <th class="px-4 py-3 font-medium">课时数</th>
              <th class="px-4 py-3 font-medium">价格</th>
              <th class="px-4 py-3 font-medium">教练</th>
              <th class="px-4 py-3 font-medium">状态</th>
              <th class="px-4 py-3 font-medium text-right">操作</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-50">
            <tr v-for="c in filteredCourses" :key="c.id" class="hover:bg-gray-50 transition">
              <td class="px-4 py-3 font-medium text-gray-800">{{ c.name }}</td>
              <td class="px-4 py-3 text-gray-500">{{ c.duration_hours }}h</td>
              <td class="px-4 py-3 text-gray-700">¥{{ c.price }}</td>
              <td class="px-4 py-3 text-gray-500">{{ getCoachName(c.coach_id) }}</td>
              <td class="px-4 py-3">
                <span class="text-xs px-2 py-0.5 rounded-full" :class="c.status === 'active' ? 'text-green-600 bg-green-50' : 'text-gray-500 bg-gray-100'">
                  {{ c.status === 'active' ? '✅ 上架' : '⏸️ 下架' }}
                </span>
              </td>
              <td class="px-4 py-3 text-right">
                <button @click="openCourseModal(c)" class="text-blue-600 hover:text-blue-800 text-xs mr-2">编辑</button>
              </td>
            </tr>
            <tr v-if="filteredCourses.length === 0">
              <td colspan="6" class="px-4 py-8 text-center text-gray-500">暂无课程数据</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ==================== 上课记录 Tab ==================== -->
    <div v-if="activeTab === 'sessions'">
      <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex gap-3 items-center flex-wrap">
        <input v-model="sessionSearch" placeholder="🔍 搜索记录..." class="px-3 py-2 border border-gray-200 rounded-lg text-sm w-60 outline-none focus:ring-2 focus:ring-blue-500">
        <span class="text-sm text-gray-500 ml-auto">共 {{ filteredSessions.length }} 条记录</span>
        <button @click="openSessionModal()" class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition"><Icon name="plus" class="inline w-4 h-4 -mt-0.5 mr-1" /> 添加记录</button>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
        <table class="w-full text-sm">
          <thead class="bg-gray-50 text-gray-500 text-left">
            <tr>
              <th class="px-4 py-3 font-medium">日期</th>
              <th class="px-4 py-3 font-medium">学员</th>
              <th class="px-4 py-3 font-medium">教练</th>
              <th class="px-4 py-3 font-medium">课程</th>
              <th class="px-4 py-3 font-medium">课时</th>
              <th class="px-4 py-3 font-medium">状态</th>
              <th class="px-4 py-3 font-medium">备注</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-50">
            <tr v-for="s in filteredSessions" :key="s.id" class="hover:bg-gray-50 transition">
              <td class="px-4 py-3 text-gray-500">{{ s.session_date }}</td>
              <td class="px-4 py-3 font-medium text-gray-800">{{ getStudentName(s.student_id) }}</td>
              <td class="px-4 py-3 text-gray-500">{{ getCoachName(s.coach_id) }}</td>
              <td class="px-4 py-3 text-gray-500">{{ getCourseName(s.course_id) }}</td>
              <td class="px-4 py-3 text-gray-500">{{ s.duration_hours }}h</td>
              <td class="px-4 py-3">
                <span class="text-xs px-2 py-0.5 rounded-full" :class="sessionStatusClass(s.status)">
                  {{ sessionStatusLabel(s.status) }}
                </span>
              </td>
              <td class="px-4 py-3 text-gray-500 max-w-xs truncate">{{ s.note || '-' }}</td>
            </tr>
            <tr v-if="filteredSessions.length === 0">
              <td colspan="7" class="px-4 py-8 text-center text-gray-500">暂无上课记录</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ==================== 收款 Tab ==================== -->
    <div v-if="activeTab === 'payments'">
      <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex gap-3 items-center flex-wrap">
        <input v-model="paymentSearch" placeholder="🔍 搜索收款..." class="px-3 py-2 border border-gray-200 rounded-lg text-sm w-60 outline-none focus:ring-2 focus:ring-blue-500">
        <span class="text-sm text-gray-500 ml-auto">共 {{ filteredPayments.length }} 条收款</span>
        <button @click="openPaymentModal()" class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition"><Icon name="plus" class="inline w-4 h-4 -mt-0.5 mr-1" /> 添加收款</button>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
        <table class="w-full text-sm">
          <thead class="bg-gray-50 text-gray-500 text-left">
            <tr>
              <th class="px-4 py-3 font-medium">学员</th>
              <th class="px-4 py-3 font-medium">关联课程</th>
              <th class="px-4 py-3 font-medium">金额</th>
              <th class="px-4 py-3 font-medium">收款方式</th>
              <th class="px-4 py-3 font-medium">状态</th>
              <th class="px-4 py-3 font-medium">日期</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-50">
            <tr v-for="p in filteredPayments" :key="p.id" class="hover:bg-gray-50 transition">
              <td class="px-4 py-3 font-medium text-gray-800">{{ getStudentName(p.student_id) }}</td>
              <td class="px-4 py-3 text-gray-500">{{ getSessionLabel(p.session_id) }}</td>
              <td class="px-4 py-3 text-gray-700 font-medium">¥{{ p.amount }}</td>
              <td class="px-4 py-3 text-gray-500">{{ p.payment_method || '-' }}</td>
              <td class="px-4 py-3">
                <span class="text-xs px-2 py-0.5 rounded-full" :class="p.status === 'paid' ? 'text-green-600 bg-green-50' : 'text-yellow-600 bg-yellow-50'">
                  {{ p.status === 'paid' ? '✅ 已收' : '⏳ 待收' }}
                </span>
              </td>
              <td class="px-4 py-3 text-gray-500">{{ fmtDate(p.created_at) }}</td>
            </tr>
            <tr v-if="filteredPayments.length === 0">
              <td colspan="6" class="px-4 py-8 text-center text-gray-500">暂无收款记录</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ==================== 教练弹窗 ==================== -->
    <Teleport to="body">
      <div v-if="coachModalOpen" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" @click.self="coachModalOpen = false">
        <div class="bg-white rounded-2xl shadow-xl w-full max-w-md mx-4">
          <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
            <h3 class="font-bold text-gray-800">{{ coachForm.id ? '编辑教练' : '添加教练' }}</h3>
            <button @click="coachModalOpen = false" class="text-gray-500 hover:text-gray-600 text-lg">✕</button>
          </div>
          <div class="px-6 py-4 space-y-4">
            <div>
              <label class="block text-sm text-gray-600 mb-1">姓名 <span class="text-red-400">*</span></label>
              <input v-model="coachForm.name" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" placeholder="教练姓名">
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">电话</label>
              <input v-model="coachForm.phone" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" placeholder="联系电话">
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">擅长领域（逗号分隔）</label>
              <input v-model="coachForm.specialtiesStr" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" placeholder="如：正手,反手,发球">
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">课时费（元/h） <span class="text-red-400">*</span></label>
              <input v-model.number="coachForm.hourly_rate" type="number" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" placeholder="500">
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">状态</label>
              <select v-model="coachForm.status" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
                <option value="active">在职</option>
                <option value="inactive">停用</option>
              </select>
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">简介</label>
              <textarea v-model="coachForm.bio" rows="2" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none" placeholder="教练简介"></textarea>
            </div>
          </div>
          <div class="px-6 py-4 border-t border-gray-100 flex justify-end gap-3">
            <button @click="coachModalOpen = false" class="px-4 py-2 rounded-lg text-sm text-gray-500 hover:bg-gray-100 transition">取消</button>
            <button @click="saveCoach" :disabled="savingCoaching" class="px-4 py-2 rounded-lg text-sm bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition">{{ savingCoaching ? '保存中...' : '保存' }}</button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ==================== 学员弹窗 ==================== -->
    <Teleport to="body">
      <div v-if="studentModalOpen" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" @click.self="studentModalOpen = false">
        <div class="bg-white rounded-2xl shadow-xl w-full max-w-md mx-4">
          <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
            <h3 class="font-bold text-gray-800">{{ studentForm.id ? '编辑学员' : '添加学员' }}</h3>
            <button @click="studentModalOpen = false" class="text-gray-500 hover:text-gray-600 text-lg">✕</button>
          </div>
          <div class="px-6 py-4 space-y-4">
            <div>
              <label class="block text-sm text-gray-600 mb-1">姓名 <span class="text-red-400">*</span></label>
              <input v-model="studentForm.name" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" placeholder="学员姓名">
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">电话</label>
              <input v-model="studentForm.phone" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" placeholder="联系电话">
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">球技水平</label>
              <select v-model="studentForm.level" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
                <option value="">未设定</option>
                <option value="beginner">初级</option>
                <option value="intermediate">中级</option>
                <option value="advanced">高级</option>
              </select>
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">备注</label>
              <textarea v-model="studentForm.note" rows="2" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none" placeholder="备注"></textarea>
            </div>
          </div>
          <div class="px-6 py-4 border-t border-gray-100 flex justify-end gap-3">
            <button @click="studentModalOpen = false" class="px-4 py-2 rounded-lg text-sm text-gray-500 hover:bg-gray-100 transition">取消</button>
            <button @click="saveStudent" :disabled="savingCoaching" class="px-4 py-2 rounded-lg text-sm bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition">{{ savingCoaching ? '保存中...' : '保存' }}</button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ==================== 课程弹窗 ==================== -->
    <Teleport to="body">
      <div v-if="courseModalOpen" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" @click.self="courseModalOpen = false">
        <div class="bg-white rounded-2xl shadow-xl w-full max-w-md mx-4">
          <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
            <h3 class="font-bold text-gray-800">{{ courseForm.id ? '编辑课程' : '添加课程' }}</h3>
            <button @click="courseModalOpen = false" class="text-gray-500 hover:text-gray-600 text-lg">✕</button>
          </div>
          <div class="px-6 py-4 space-y-4">
            <div>
              <label class="block text-sm text-gray-600 mb-1">课程名称 <span class="text-red-400">*</span></label>
              <input v-model="courseForm.name" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" placeholder="课程名称">
            </div>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-sm text-gray-600 mb-1">课时数（h） <span class="text-red-400">*</span></label>
                <input v-model.number="courseForm.duration_hours" type="number" step="0.5" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" placeholder="1">
              </div>
              <div>
                <label class="block text-sm text-gray-600 mb-1">价格（元） <span class="text-red-400">*</span></label>
                <input v-model.number="courseForm.price" type="number" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" placeholder="500">
              </div>
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">教练</label>
              <select v-model="courseForm.coach_id" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
                <option value="">不指定</option>
                <option v-for="c in coaches" :key="c.id" :value="c.id">{{ c.name }}</option>
              </select>
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">状态</label>
              <select v-model="courseForm.status" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
                <option value="active">上架</option>
                <option value="inactive">下架</option>
              </select>
            </div>
          </div>
          <div class="px-6 py-4 border-t border-gray-100 flex justify-end gap-3">
            <button @click="courseModalOpen = false" class="px-4 py-2 rounded-lg text-sm text-gray-500 hover:bg-gray-100 transition">取消</button>
            <button @click="saveCourse" :disabled="savingCoaching" class="px-4 py-2 rounded-lg text-sm bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition">{{ savingCoaching ? '保存中...' : '保存' }}</button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ==================== 上课记录弹窗 ==================== -->
    <Teleport to="body">
      <div v-if="sessionModalOpen" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" @click.self="sessionModalOpen = false">
        <div class="bg-white rounded-2xl shadow-xl w-full max-w-md mx-4">
          <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
            <h3 class="font-bold text-gray-800">添加上课记录</h3>
            <button @click="sessionModalOpen = false" class="text-gray-500 hover:text-gray-600 text-lg">✕</button>
          </div>
          <div class="px-6 py-4 space-y-4">
            <div>
              <label class="block text-sm text-gray-600 mb-1">学员 <span class="text-red-400">*</span></label>
              <select v-model="sessionForm.student_id" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
                <option value="">选择学员</option>
                <option v-for="s in students" :key="s.id" :value="s.id">{{ s.name }}</option>
              </select>
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">教练 <span class="text-red-400">*</span></label>
              <select v-model="sessionForm.coach_id" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
                <option value="">选择教练</option>
                <option v-for="c in coaches" :key="c.id" :value="c.id">{{ c.name }}</option>
              </select>
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">课程 <span class="text-red-400">*</span></label>
              <select v-model="sessionForm.course_id" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
                <option value="">选择课程</option>
                <option v-for="c in courses" :key="c.id" :value="c.id">{{ c.name }}</option>
              </select>
            </div>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-sm text-gray-600 mb-1">日期 <span class="text-red-400">*</span></label>
                <input v-model="sessionForm.session_date" type="date" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
              </div>
              <div>
                <label class="block text-sm text-gray-600 mb-1">课时（h）</label>
                <input v-model.number="sessionForm.duration_hours" type="number" step="0.5" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" placeholder="1">
              </div>
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">备注</label>
              <textarea v-model="sessionForm.note" rows="2" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none" placeholder="上课备注"></textarea>
            </div>
          </div>
          <div class="px-6 py-4 border-t border-gray-100 flex justify-end gap-3">
            <button @click="sessionModalOpen = false" class="px-4 py-2 rounded-lg text-sm text-gray-500 hover:bg-gray-100 transition">取消</button>
            <button @click="saveSession" :disabled="savingCoaching" class="px-4 py-2 rounded-lg text-sm bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition">{{ savingCoaching ? '保存中...' : '保存' }}</button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ==================== 收款弹窗 ==================== -->
    <Teleport to="body">
      <div v-if="paymentModalOpen" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" @click.self="paymentModalOpen = false">
        <div class="bg-white rounded-2xl shadow-xl w-full max-w-md mx-4">
          <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
            <h3 class="font-bold text-gray-800">添加收款</h3>
            <button @click="paymentModalOpen = false" class="text-gray-500 hover:text-gray-600 text-lg">✕</button>
          </div>
          <div class="px-6 py-4 space-y-4">
            <div>
              <label class="block text-sm text-gray-600 mb-1">学员 <span class="text-red-400">*</span></label>
              <select v-model="paymentForm.student_id" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
                <option value="">选择学员</option>
                <option v-for="s in students" :key="s.id" :value="s.id">{{ s.name }}</option>
              </select>
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">关联上课记录</label>
              <select v-model="paymentForm.session_id" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
                <option value="">不关联</option>
                <option v-for="s in filteredSessionsForPayment" :key="s.id" :value="s.id">{{ fmtDate(s.session_date) }} - {{ getStudentName(s.student_id) }} - {{ getCourseName(s.course_id) }}</option>
              </select>
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">金额（元） <span class="text-red-400">*</span></label>
              <input v-model.number="paymentForm.amount" type="number" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" placeholder="0">
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">收款方式</label>
              <select v-model="paymentForm.payment_method" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
                <option value="">未选择</option>
                <option value="微信">微信</option>
                <option value="支付宝">支付宝</option>
                <option value="银行卡">银行卡</option>
                <option value="现金">现金</option>
              </select>
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">状态</label>
              <select v-model="paymentForm.status" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
                <option value="paid">已收</option>
                <option value="pending">待收</option>
              </select>
            </div>
          </div>
          <div class="px-6 py-4 border-t border-gray-100 flex justify-end gap-3">
            <button @click="paymentModalOpen = false" class="px-4 py-2 rounded-lg text-sm text-gray-500 hover:bg-gray-100 transition">取消</button>
            <button @click="savePayment" :disabled="savingCoaching" class="px-4 py-2 rounded-lg text-sm bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition">{{ savingCoaching ? '保存中...' : '保存' }}</button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- Toast -->
    <Teleport to="body">
      <div v-if="toast" class="fixed top-6 right-6 z-[999] bg-green-500 text-white px-5 py-3 rounded-xl shadow-lg text-sm font-medium" style="animation: fadeIn 0.3s ease">
        {{ toast }}
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import Icon from '../components/icons/Icons.vue'

// ===== Tab =====
const tabs = [
  { key: 'coaches', label: '教练' },
  { key: 'students', label: '学员' },
  { key: 'courses', label: '课程' },
  { key: 'sessions', label: '上课记录' },
  { key: 'payments', label: '收款' },
]
const activeTab = ref('coaches')

// ===== Data =====
const coaches = ref([])
const students = ref([])
const courses = ref([])
const sessions = ref([])
const payments = ref([])

// ===== Search =====
const coachSearch = ref('')
const studentSearch = ref('')
const courseSearch = ref('')
const sessionSearch = ref('')
const paymentSearch = ref('')

// ===== Toast =====
const toast = ref('')
function showToast(msg) {
  toast.value = msg
  setTimeout(() => { toast.value = '' }, 2000)
}

// ===== Helpers =====
function parseJson(val) {
  if (Array.isArray(val)) return val
  try { return JSON.parse(val) } catch { return [] }
}
function levelLabel(l) {
  return { beginner: '🟢 初级', intermediate: '🟡 中级', advanced: '🔴 高级' }[l] || '未设定'
}
function levelClass(l) {
  return {
    beginner: 'text-green-600 bg-green-50',
    intermediate: 'text-yellow-600 bg-yellow-50',
    advanced: 'text-red-600 bg-red-50'
  }[l] || 'text-gray-500 bg-gray-50'
}
function sessionStatusLabel(s) {
  return { completed: '✅ 已完成', scheduled: '📅 已预约', cancelled: '❌ 已取消' }[s] || s || '未设定'
}
function sessionStatusClass(s) {
  return {
    completed: 'text-green-600 bg-green-50',
    scheduled: 'text-blue-600 bg-blue-50',
    cancelled: 'text-red-600 bg-red-50'
  }[s] || 'text-gray-500 bg-gray-50'
}
function getCoachName(id) {
  if (!id) return '-'
  return coaches.value.find(c => c.id === id)?.name || '-'
}
function getStudentName(id) {
  if (!id) return '-'
  return students.value.find(s => s.id === id)?.name || '-'
}
function getCourseName(id) {
  if (!id) return '-'
  return courses.value.find(c => c.id === id)?.name || '-'
}
function getSessionLabel(id) {
  if (!id) return '-'
  const s = sessions.value.find(x => x.id === id)
  if (!s) return '-'
  return `${getCourseName(s.course_id)} (${s.session_date})`
}
function fmtDate(d) {
  if (!d) return '-'
  return d.slice(0, 10)
}
function today() {
  return new Date().toISOString().slice(0, 10)
}

// ===== Filtered lists =====
const filteredCoaches = computed(() => {
  if (!coachSearch.value) return coaches.value
  const kw = coachSearch.value.toLowerCase()
  return coaches.value.filter(c =>
    (c.name || '').toLowerCase().includes(kw) ||
    (c.phone || '').includes(kw)
  )
})
const filteredStudents = computed(() => {
  if (!studentSearch.value) return students.value
  const kw = studentSearch.value.toLowerCase()
  return students.value.filter(s =>
    (s.name || '').toLowerCase().includes(kw) ||
    (s.phone || '').includes(kw)
  )
})
const filteredCourses = computed(() => {
  if (!courseSearch.value) return courses.value
  const kw = courseSearch.value.toLowerCase()
  return courses.value.filter(c =>
    (c.name || '').toLowerCase().includes(kw)
  )
})
const filteredSessions = computed(() => {
  if (!sessionSearch.value) return sessions.value
  const kw = sessionSearch.value.toLowerCase()
  return sessions.value.filter(s => {
    const studentName = getStudentName(s.student_id)
    const coachName = getCoachName(s.coach_id)
    const courseName = getCourseName(s.course_id)
    return studentName.toLowerCase().includes(kw) ||
      coachName.toLowerCase().includes(kw) ||
      courseName.toLowerCase().includes(kw) ||
      (s.session_date || '').includes(kw)
  })
})
const filteredPayments = computed(() => {
  if (!paymentSearch.value) return payments.value
  const kw = paymentSearch.value.toLowerCase()
  return payments.value.filter(p => {
    const studentName = getStudentName(p.student_id)
    return studentName.toLowerCase().includes(kw) ||
      (p.payment_method || '').includes(kw)
  })
})
const filteredSessionsForPayment = computed(() => {
  if (!paymentForm.value.student_id) return sessions.value
  return sessions.value.filter(s => s.student_id === paymentForm.value.student_id)
})

// ===== Data Loading =====
async function loadCoaches() {
  const { data } = await supabase.from('coaches').select('*').order('created_at', { ascending: true })
  coaches.value = data || []
}
async function loadStudents() {
  const { data } = await supabase.from('students').select('*').order('created_at', { ascending: true })
  students.value = data || []
}
async function loadCourses() {
  const { data } = await supabase.from('courses').select('*').order('created_at', { ascending: true })
  courses.value = data || []
}
async function loadSessions() {
  const { data } = await supabase.from('coaching_sessions').select('*').order('session_date', { ascending: false })
  sessions.value = data || []
}
async function loadPayments() {
  const { data } = await supabase.from('coaching_payments').select('*').order('created_at', { ascending: false })
  payments.value = data || []
}

// ===== Seed Data =====
async function seedIfEmpty() {
  // Seed coaches
  const { data: existingCoaches } = await supabase.from('coaches').select('id').limit(1)
  if (!existingCoaches || existingCoaches.length === 0) {
    await supabase.from('coaches').insert([{
      name: '王孟南',
      phone: '',
      specialties: ['乒乓球', '正手弧圈球', '反手拧拉'],
      hourly_rate: 500,
      status: 'active',
      bio: '资深乒乓球教练'
    }])
  }

  // Seed courses
  const { data: existingCourses } = await supabase.from('courses').select('id').limit(1)
  if (!existingCourses || existingCourses.length === 0) {
    // Need to get coach id first
    const { data: coachData } = await supabase.from('coaches').select('id').limit(1)
    const coachId = coachData?.[0]?.id
    await supabase.from('courses').insert([
      { name: '一对一私教', duration_hours: 1, price: 500, coach_id: coachId, status: 'active' },
      { name: '三天两夜集训', duration_hours: 24, price: 6800, coach_id: coachId, status: 'active' },
      { name: '线上录播课', duration_hours: 10, price: 299, coach_id: null, status: 'active' }
    ])
  }

  // Reload after seeding
  await Promise.all([loadCoaches(), loadStudents(), loadCourses(), loadSessions(), loadPayments()])
}

// ===== Coach CRUD =====
const coachModalOpen = ref(false)
// 5 个模态共享一把保存锁（同时只会有一个模态打开）
const savingCoaching = ref(false)
const coachForm = ref({ id: null, name: '', phone: '', specialtiesStr: '', hourly_rate: 500, status: 'active', bio: '' })

function openCoachModal(row) {
  if (row) {
    coachForm.value = {
      id: row.id,
      name: row.name || '',
      phone: row.phone || '',
      specialtiesStr: parseJson(row.specialties).join(','),
      hourly_rate: row.hourly_rate || 0,
      status: row.status || 'active',
      bio: row.bio || ''
    }
  } else {
    coachForm.value = { id: null, name: '', phone: '', specialtiesStr: '', hourly_rate: 500, status: 'active', bio: '' }
  }
  coachModalOpen.value = true
}

async function saveCoach() {
  const f = coachForm.value
  if (!f.name) return showToast('请填写教练姓名')
  if (savingCoaching.value) return
  savingCoaching.value = true
  try {
    const payload = {
      name: f.name,
      phone: f.phone || null,
      specialties: f.specialtiesStr ? f.specialtiesStr.split(',').map(s => s.trim()).filter(Boolean) : [],
      hourly_rate: f.hourly_rate || 0,
      status: f.status,
      bio: f.bio || null
    }
    if (f.id) {
      await supabase.from('coaches').update(payload).eq('id', f.id)
      showToast('教练已更新')
    } else {
      await supabase.from('coaches').insert([payload])
      showToast('教练已添加')
    }
    coachModalOpen.value = false
    await loadCoaches()
  } finally {
    savingCoaching.value = false
  }
}

// ===== Student CRUD =====
const studentModalOpen = ref(false)
const studentForm = ref({ id: null, name: '', phone: '', level: '', note: '' })

function openStudentModal(row) {
  if (row) {
    studentForm.value = { id: row.id, name: row.name || '', phone: row.phone || '', level: row.level || '', note: row.note || '' }
  } else {
    studentForm.value = { id: null, name: '', phone: '', level: '', note: '' }
  }
  studentModalOpen.value = true
}

async function saveStudent() {
  const f = studentForm.value
  if (!f.name) return showToast('请填写学员姓名')
  if (savingCoaching.value) return
  savingCoaching.value = true
  try {
    const payload = { name: f.name, phone: f.phone || null, level: f.level || null, note: f.note || null }
    if (f.id) {
      await supabase.from('students').update(payload).eq('id', f.id)
      showToast('学员已更新')
    } else {
      await supabase.from('students').insert([payload])
      showToast('学员已添加')
    }
    studentModalOpen.value = false
    await loadStudents()
  } finally {
    savingCoaching.value = false
  }
}

// ===== Course CRUD =====
const courseModalOpen = ref(false)
const courseForm = ref({ id: null, name: '', duration_hours: 1, price: 0, coach_id: '', status: 'active' })

function openCourseModal(row) {
  if (row) {
    courseForm.value = {
      id: row.id, name: row.name || '', duration_hours: row.duration_hours || 1,
      price: row.price || 0, coach_id: row.coach_id || '', status: row.status || 'active'
    }
  } else {
    courseForm.value = { id: null, name: '', duration_hours: 1, price: 0, coach_id: '', status: 'active' }
  }
  courseModalOpen.value = true
}

async function saveCourse() {
  const f = courseForm.value
  if (!f.name) return showToast('请填写课程名称')
  if (savingCoaching.value) return
  savingCoaching.value = true
  try {
    const payload = {
      name: f.name, duration_hours: f.duration_hours || 1, price: f.price || 0,
      coach_id: f.coach_id || null, status: f.status
    }
    if (f.id) {
      await supabase.from('courses').update(payload).eq('id', f.id)
      showToast('课程已更新')
    } else {
      await supabase.from('courses').insert([payload])
      showToast('课程已添加')
    }
    courseModalOpen.value = false
    await loadCourses()
  } finally {
    savingCoaching.value = false
  }
}

// ===== Session CRUD =====
const sessionModalOpen = ref(false)
const sessionForm = ref({ student_id: '', coach_id: '', course_id: '', session_date: '', duration_hours: 1, note: '', status: 'completed' })

function openSessionModal() {
  sessionForm.value = { student_id: '', coach_id: '', course_id: '', session_date: today(), duration_hours: 1, note: '', status: 'completed' }
  sessionModalOpen.value = true
}

async function saveSession() {
  const f = sessionForm.value
  if (!f.student_id || !f.coach_id || !f.course_id || !f.session_date) {
    return showToast('请填写完整信息')
  }
  if (savingCoaching.value) return
  savingCoaching.value = true
  try {
    await supabase.from('coaching_sessions').insert([{
      student_id: f.student_id,
      coach_id: f.coach_id,
      course_id: f.course_id,
      session_date: f.session_date,
      duration_hours: f.duration_hours || 1,
      status: f.status || 'completed',
      note: f.note || null
    }])
    sessionModalOpen.value = false
    showToast('上课记录已添加')
    await loadSessions()
  } finally {
    savingCoaching.value = false
  }
}

// ===== Payment CRUD =====
const paymentModalOpen = ref(false)
const paymentForm = ref({ student_id: '', session_id: '', amount: 0, payment_method: '', status: 'paid' })

function openPaymentModal() {
  paymentForm.value = { student_id: '', session_id: '', amount: 0, payment_method: '', status: 'paid' }
  paymentModalOpen.value = true
}

async function savePayment() {
  const f = paymentForm.value
  if (!f.student_id) return showToast('请选择学员')
  if (!f.amount || f.amount <= 0) return showToast('请填写金额')
  if (savingCoaching.value) return
  savingCoaching.value = true
  try {
    await supabase.from('coaching_payments').insert([{
      student_id: f.student_id,
      session_id: f.session_id || null,
      amount: f.amount,
      payment_method: f.payment_method || null,
      status: f.status || 'paid'
    }])
    paymentModalOpen.value = false
    showToast('收款记录已添加')
    await loadPayments()
  } finally {
    savingCoaching.value = false
  }
}

// ===== Init =====
onMounted(async () => {
  await seedIfEmpty()
})
</script>