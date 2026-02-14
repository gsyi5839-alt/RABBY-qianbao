import React from 'react';
import { useNavigate } from 'react-router-dom';

/**
 * Placeholder — generic "coming soon" page for routes not yet implemented.
 *
 * Accepts a `title` prop to display the name of the feature.
 * Includes a back button to return to the previous page.
 */
interface PlaceholderProps {
  title: string;
}

const Placeholder: React.FC<PlaceholderProps> = ({ title }) => {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      {/* Header */}
      <header className="flex items-center px-4 pt-12 pb-4 bg-white border-b border-gray-100">
        <button
          onClick={() => navigate(-1)}
          className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-gray-100 transition-colors"
        >
          <svg className="w-5 h-5 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="flex-1 text-lg font-semibold text-gray-900 text-center pr-10">
          {title}
        </h1>
      </header>

      {/* Content */}
      <div className="flex-1 flex flex-col items-center justify-center px-6">
        {/* Icon */}
        <div className="w-20 h-20 bg-gray-100 rounded-2xl flex items-center justify-center mb-6">
          <svg className="w-10 h-10 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={1.5}
              d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"
            />
          </svg>
        </div>

        <h2 className="text-xl font-semibold text-gray-900 mb-2">{title}</h2>
        <p className="text-sm text-gray-400 text-center max-w-xs">
          This feature is coming soon. Stay tuned for updates!
        </p>

        {/* Back to dashboard */}
        <button
          onClick={() => navigate('/dashboard')}
          className="mt-8 px-6 py-3 bg-blue-500 text-white text-sm font-medium rounded-xl
                     hover:bg-blue-600 active:scale-[0.98] transition-all"
        >
          Back to Dashboard
        </button>
      </div>
    </div>
  );
};

export default Placeholder;
